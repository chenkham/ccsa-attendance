import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:uuid/uuid.dart';
import '../../db/database_helper.dart';
import '../../models/attendance_session.dart';
import '../../models/student.dart';
import '../../models/subject.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/csv_export_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/marquee_text.dart';
import '../../widgets/custom_cards.dart';
import '../../widgets/doodle_art.dart';
import '../../widgets/dynamic_qr_display.dart';
import '../../widgets/micro_interactions.dart';
import '../../widgets/responsive_layout.dart';

class DynamicQrSessionPage extends StatefulWidget {
  final Subject subject;

  const DynamicQrSessionPage({super.key, required this.subject});

  @override
  State<DynamicQrSessionPage> createState() => _DynamicQrSessionPageState();
}

class _DynamicQrSessionPageState extends State<DynamicQrSessionPage> {
  late String _sessionId;
  final bool _isLab = false;
  bool _isFullScreen = false;
  late bool _geofenceEnabled;
  late double _targetLat;
  late double _targetLng;
  late double _radiusMeters;

  List<Student> _enrolledStudents = [];
  final Set<String> _presentStudentIds = {}; // identifiers (id/roll/name) for marking state
  final Set<String> _presentStudentKeys = {}; // unique student keys for accurate count
  int _livePresentCount = 0;
  bool _allowPop = false; // set true when finishing/cancel so PopScope lets us leave
  Timer? _dbPollTimer;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _sessionId = const Uuid().v4();
    _geofenceEnabled = widget.subject.geofenceEnabled;
    _targetLat = widget.subject.latitude ?? LocationService.defaultCcsaLatitude;
    _targetLng = widget.subject.longitude ?? LocationService.defaultCcsaLongitude;
    _radiusMeters = widget.subject.radiusMeters;

    _loadEnrolledStudents();

    // Poll cloud every 800ms — the teacher needs near-instant turnout feedback
    _dbPollTimer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      _pollLiveAttendees();
    });
  }

  @override
  void dispose() {
    _dbPollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadEnrolledStudents() async {
    setState(() => _isLoading = true);
    List<Student> list = [];

    try {
      // Cloud-first: the local cache can be stale (e.g. wiped by reinstall or
      // enrollment changed on another device), which caused "2 enrolled but
      // session shows 1". The cloud roster filtered by the subject's enrolled
      // ids is authoritative.
      final cloudStds = await ApiService.instance.getRegisteredStudents(
        course: widget.subject.course,
        semester: widget.subject.semester,
      );
      if (cloudStds.isNotEmpty) {
        final enrolledSet = widget.subject.enrolledStudentIds.toSet();
        if (enrolledSet.isNotEmpty) {
          list = cloudStds.where((s) => enrolledSet.contains(s.id)).toList();
        }
        if (list.isEmpty) list = cloudStds;
      }

      // Local fallback only when the cloud is unreachable
      if (list.isEmpty) {
        try {
          list = await DatabaseHelper.instance.getStudentsForSubject(widget.subject.id);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Error loading students for QR: $e');
    } finally {
      if (mounted) {
        setState(() {
          _enrolledStudents = list;
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _pollLiveAttendees() async {
    // Poll live scans DIRECTLY from Hostinger MySQL Cloud (Single Source of Truth).
    // Count UNIQUE students (one row per record) — never aggregate identifiers,
    // which inflated turnout (3/2 for a single scan).
    try {
      final rows = await ApiService.instance.getSessionTurnoutLive(_sessionId);
      if (mounted && rows.isNotEmpty) {
        final identifiers = <String>{};
        final keys = <String>{};
        for (final row in rows) {
          final sid = row['student_id']?.toString() ?? '';
          final sroll = row['student_roll_no']?.toString() ?? '';
          final sname = row['student_name']?.toString() ?? '';
          if (sid.isNotEmpty) {
            identifiers.add(sid);
            keys.add('id:$sid');
          } else if (sroll.isNotEmpty) {
            identifiers.add(sroll);
            keys.add('roll:$sroll');
          } else if (sname.isNotEmpty) {
            identifiers.add(sname.toLowerCase());
            keys.add('name:${sname.toLowerCase()}');
          }
        }
        final changed = keys.length != _presentStudentKeys.length;
        setState(() {
          _presentStudentIds.addAll(identifiers);
          _presentStudentKeys.addAll(keys);
          _livePresentCount = _presentStudentKeys.length;
        });
        if (changed) AppTheme.triggerLightHaptic();
      }
    } catch (_) {}
  }

  Future<void> _markStudentPresentManually(Student student) async {
    if (_presentStudentIds.contains(student.id)) return;

    AppTheme.triggerSuccessHaptic();
    setState(() {
      _presentStudentIds.add(student.id);
      _presentStudentKeys.add('id:${student.id}');
      _livePresentCount = _presentStudentKeys.length;
    });

    // Write manual mark directly to Cloud Database
    final success = await ApiService.instance.recordStudentAttendanceLive(
      sessionId: _sessionId,
      studentId: student.id,
      email: student.email ?? '',
      name: student.name,
      rollNo: student.classRollNo,
      subjectId: widget.subject.id,
      subjectCode: widget.subject.code,
      subjectName: widget.subject.name,
      teacherEmail: widget.subject.teacherEmail,
      markedBy: 'manual_teacher',
    );

    if (success) {
      final record = AttendanceRecord(
        id: const Uuid().v4(),
        sessionId: _sessionId,
        studentId: student.id,
        studentRollNo: student.classRollNo,
        studentName: student.name,
        status: 'present',
        markedBy: 'manual_teacher',
      );
      try {
        final db = await DatabaseHelper.instance.database;
        await db.insert('attendance_records', record.toMap());
      } catch (_) {}
    }
  }

  void _showManualAttendanceDialog() {
    AppTheme.triggerLightHaptic();
    String search = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgLight,
      builder: (bCtx) => StatefulBuilder(
        builder: (context, setModalState) {
          final filtered = _enrolledStudents.where((s) {
            if (search.isEmpty) return true;
            final q = search.toLowerCase();
            return s.name.toLowerCase().contains(q) || s.classRollNo.toLowerCase().contains(q);
          }).toList();

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.borderLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: 14),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Manual Roll Call Override',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16.5, color: AppTheme.royalNavy),
                          ),
                          Text('Mark students present in case of device issues', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(LucideIcons.x, size: 20),
                        onPressed: () => Navigator.pop(bCtx),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Search student by name or roll no...',
                      prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppTheme.textSecondary),
                      filled: true,
                      fillColor: AppTheme.bgLight,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      border: OutlineInputBorder(borderRadius: AppTheme.cardRadius, borderSide: const BorderSide(color: AppTheme.borderLight)),
                    ),
                    onChanged: (v) => setModalState(() => search = v.trim()),
                  ),
                ),
                const SizedBox(height: 12),

                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderLight),
                    itemBuilder: (context, index) {
                      final s = filtered[index];
                      final isMarked = _presentStudentIds.contains(s.id) ||
                          (s.classRollNo.isNotEmpty && _presentStudentIds.contains(s.classRollNo)) ||
                          (s.name.isNotEmpty && _presentStudentIds.contains(s.name.toLowerCase())) ||
                          (s.email != null && s.email!.isNotEmpty && _presentStudentIds.contains(s.email!.toLowerCase()));
                      final rollNo = s.classRollNo.isNotEmpty ? s.classRollNo : '${index + 1}';

                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundColor: isMarked ? AppTheme.emeraldGreenBg : AppTheme.bgLight,
                          child: Text(
                            rollNo,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 11,
                              color: isMarked ? const Color(0xFF047857) : AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        title: Text(s.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5)),
                        subtitle: Text('Roll: $rollNo', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
                        trailing: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isMarked ? AppTheme.emeraldGreen : AppTheme.royalNavy,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: AppTheme.pillRadius),
                          ),
                          onPressed: isMarked
                              ? null
                              : () {
                                  _markStudentPresentManually(s);
                                  setModalState(() {});
                                },
                          child: Text(
                            isMarked ? 'Present' : 'Mark Present',
                            style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _finishAndSaveSession() async {
    _dbPollTimer?.cancel();
    AppTheme.triggerSuccessHaptic();

    final user = AuthService.instance.currentUser;

    final List<AttendanceRecord> records = [];
    final Set<String> handledPresentIds = {};

    bool isStudentPresent(Student std) {
      for (final pid in _presentStudentIds) {
        if (pid == std.id || 
            (std.email != null && std.email!.isNotEmpty && pid.toLowerCase() == std.email!.toLowerCase()) ||
            (std.classRollNo.isNotEmpty && pid == std.classRollNo)) {
          handledPresentIds.add(pid);
          return true;
        }
      }
      return false;
    }

    for (final student in _enrolledStudents) {
      final isPresent = isStudentPresent(student);
      records.add(AttendanceRecord(
        id: const Uuid().v4(),
        sessionId: _sessionId,
        studentId: student.id,
        studentRollNo: student.classRollNo,
        studentName: student.name,
        status: isPresent ? 'present' : 'absent',
        markedBy: isPresent ? 'totp_qr' : 'system',
      ));
    }

    // Also include any present IDs that weren't matched in _enrolledStudents
    for (final id in _presentStudentIds) {
      if (!handledPresentIds.contains(id)) {
        records.add(AttendanceRecord(
          id: const Uuid().v4(),
          sessionId: _sessionId,
          studentId: id,
          studentRollNo: '',
          studentName: 'Student',
          status: 'present',
          markedBy: 'totp_qr',
        ));
      }
    }

    final realPresentCount = records.where((r) => r.status == 'present').length;
    final realEnrolledCount = records.length;

    final session = AttendanceSession(
      id: _sessionId,
      subjectId: widget.subject.id,
      subjectCode: widget.subject.code,
      subjectName: widget.subject.name,
      teacherEmail: user?.email ?? 'faculty@ccsa.du.ac.in',
      sessionDate: DateTime.now(),
      totalPresent: realPresentCount,
      totalEnrolled: realEnrolledCount,
      isLab: _isLab,
    );

    // Save session and records to Hostinger MySQL Database FIRST (Single Source of Truth)
    bool cloudSaved = false;
    try {
      cloudSaved = await ApiService.instance.syncAttendanceSession(session, records);
    } catch (e) {
      debugPrint('Sync attendance session cloud error: $e');
    }

    if (!cloudSaved) {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
            title: const Row(
              children: [
                Icon(LucideIcons.cloudOff, color: AppTheme.crimsonRose, size: 24),
                SizedBox(width: 10),
                Text('Cloud Save Failed'),
              ],
            ),
            content: Text(
              'Could not save this session to the central university database. Please check your internet connection and tap Retry Save.',
              style: GoogleFonts.inter(fontSize: 13, height: 1.4),
            ),
            actions: [
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalNavy),
                onPressed: () {
                  Navigator.pop(ctx);
                  _finishAndSaveSession();
                },
                child: const Text('Retry Save'),
              ),
            ],
          ),
        );
      }
      return;
    }

    // Only cache to local database after confirmed success in online cloud database
    try {
      await DatabaseHelper.instance.insertAttendanceSession(session, records);
    } catch (_) {}

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: AppTheme.emeraldGreenBg,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.checkCircle2, color: AppTheme.emeraldGreen, size: 24),
              ),
              const SizedBox(width: 10),
              Text(
                'Attendance Saved',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.subject.name,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.royalNavy),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Turnout', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('${session.totalPresent} / ${session.totalEnrolled} (${session.attendancePercentage.toStringAsFixed(1)}%)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            OutlinedButton.icon(
              icon: const Icon(LucideIcons.fileSpreadsheet, size: 16, color: AppTheme.emeraldGreen),
              label: const Text('Export CSV'),
              onPressed: () {
                Navigator.pop(ctx);
                CsvExportService.instance.exportSubjectCsv(widget.subject);
                _allowPop = true;
                Navigator.pop(context, true);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalNavy, shape: RoundedRectangleBorder(borderRadius: AppTheme.pillRadius)),
              onPressed: () {
                Navigator.pop(ctx);
                _allowPop = true;
                Navigator.pop(context, true);
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // UNIQUE students present (never exceeds enrolled — can't show 3/2)
    final presentCount = _livePresentCount.clamp(0, _enrolledStudents.isEmpty ? _livePresentCount : _enrolledStudents.length);
    final totalCount = _enrolledStudents.length;
    final isWide = Responsive.isWide(context);

    // Full Screen QR Presentation Mode
    if (_isFullScreen) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (didPop) return;
          setState(() => _isFullScreen = false); // system back = leave presentation mode
        },
        child: Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Stack(
            children: [
              // Subtle doodle pattern backdrop
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(painter: DoodlePatternPainter(ink: Colors.white, opacity: 0.05, seed: 29)),
                ),
              ),
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // LIVE pulse indicator
                        PulseGlow(
                          glowColor: AppTheme.crimsonRose,
                          child: Container(
                            width: 10,
                            height: 10,
                            decoration: const BoxDecoration(color: AppTheme.crimsonRose, shape: BoxShape.circle),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LIVE SESSION',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.4,
                            color: Colors.white.withOpacity(0.65),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      widget.subject.name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 24, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        boxShadow: [
                          BoxShadow(color: AppTheme.googleBlue.withOpacity(0.25), blurRadius: 48, spreadRadius: 2),
                        ],
                      ),
                      child: DynamicQrDisplay(
                        subjectId: widget.subject.id,
                        sessionId: _sessionId,
                        size: isWide ? 300 : 250,
                        isBigScreen: true,
                        geofenceEnabled: _geofenceEnabled,
                        targetLat: _targetLat,
                        targetLng: _targetLng,
                        radiusMeters: _radiusMeters,
                      ),
                    ),
                    const SizedBox(height: 28),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(40),
                        border: Border.all(color: Colors.white.withOpacity(0.14)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(LucideIcons.userCheck, size: 16, color: AppTheme.emeraldGreen),
                          const SizedBox(width: 8),
                          Text(
                            'Present: $presentCount / $totalCount (${totalCount > 0 ? (((presentCount / totalCount) * 100).clamp(0, 100)).toStringAsFixed(0) : 0}%)',
                            style: GoogleFonts.inter(fontSize: 15, color: Colors.white, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton.filledTonal(
                  icon: const Icon(LucideIcons.x, color: Colors.white, size: 24),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.12),
                  ),
                  onPressed: () => setState(() => _isFullScreen = false),
                ),
              ),
            ],
          ),
        ),
      ),
      );
    }

    return PopScope(
      canPop: _allowPop,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _showExitChoiceDialog();
      },
      child: Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MarqueeText(
              text: widget.subject.name,
              style: GoogleFonts.plusJakartaSans(fontSize: 15.5, fontWeight: FontWeight.w700),
            ),
            Text(
              '${widget.subject.course} ${widget.subject.semesterDisplay}',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          // Fullscreen QR Mode Toggle
          IconButton(
            tooltip: 'Full Screen Projector QR',
            icon: const Icon(LucideIcons.maximize2, color: AppTheme.royalNavy),
            onPressed: () {
              setState(() => _isFullScreen = true);
              AppTheme.triggerLightHaptic();
            },
          ),
          // Manual roll call button
          IconButton(
            tooltip: 'Manual Attendance',
            icon: const Icon(LucideIcons.userCheck, color: AppTheme.royalNavy),
            onPressed: _showManualAttendanceDialog,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: BrandLoader(message: 'Preparing session…', size: 44))
          : AdaptiveContainer(
              maxWidth: 960,
              child: isWide
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Left: Dynamic QR Generator
                        Expanded(
                          flex: 5,
                          child: Center(
                            child: DynamicQrDisplay(
                              subjectId: widget.subject.id,
                              sessionId: _sessionId,
                              size: 260,
                              geofenceEnabled: _geofenceEnabled,
                              targetLat: _targetLat,
                              targetLng: _targetLng,
                              radiusMeters: _radiusMeters,
                            ),
                          ),
                        ),
                        const SizedBox(width: 32),

                        // Right: Live Turnout & Actions
                        Expanded(
                          flex: 5,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildTurnoutCard(presentCount, totalCount),
                              const SizedBox(height: 20),
                              GPayActionPill(
                                label: 'Done & Save Session',
                                icon: LucideIcons.checkCheck,
                                onPressed: _finishAndSaveSession,
                              ),
                              const SizedBox(height: 12),
                              GPayActionPill(
                                label: 'Manual Roll Call Override',
                                icon: LucideIcons.userCheck,
                                isPrimary: false,
                                onPressed: _showManualAttendanceDialog,
                              ),
                              const SizedBox(height: 12),
                              _buildCancelSessionButton(),
                            ],
                          ),
                        ),
                      ],
                    )
                  : SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          DynamicQrDisplay(
                            subjectId: widget.subject.id,
                            sessionId: _sessionId,
                            size: 240,
                            geofenceEnabled: _geofenceEnabled,
                            targetLat: _targetLat,
                            targetLng: _targetLng,
                            radiusMeters: _radiusMeters,
                          ),
                          const SizedBox(height: 20),
                          _buildTurnoutCard(presentCount, totalCount),
                          const SizedBox(height: 24),
                          GPayActionPill(
                            label: 'Done & Save Session',
                            icon: LucideIcons.checkCheck,
                            onPressed: _finishAndSaveSession,
                          ),
                          const SizedBox(height: 12),
                          _buildCancelSessionButton(),
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
      ),
    );
  }

  /// Back-press (or app-bar back) during a live session: force an explicit
  /// decision — silently abandoning the page would leave the session live in
  /// the cloud with scans (phantom class on the student side).
  Future<void> _showExitChoiceDialog() async {
    AppTheme.triggerLightHaptic();
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppTheme.amberWarningBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.alertTriangle, color: Color(0xFFB45309), size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Session is still live',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'What would you like to do with this session?',
          style: GoogleFonts.inter(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'stay'),
            child: const Text('Stay', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: const Text('Cancel Session', style: TextStyle(fontWeight: FontWeight.w700, color: AppTheme.crimsonRose)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.royalNavy,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(ctx, 'save'),
            child: const Text('Save & Exit', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (choice == 'save') {
      await _finishAndSaveSession();
    } else if (choice == 'cancel') {
      await _cancelSession();
    }
  }

  /// Cancel (discard) the session without saving anything.
  Future<void> _cancelSession() async {
    AppTheme.triggerLightHaptic();
    final markedCount = _presentStudentKeys.length;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
              decoration: BoxDecoration(
                color: AppTheme.crimsonRoseBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(LucideIcons.xCircle, color: AppTheme.crimsonRose, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Cancel Session?',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          markedCount > 0
              ? '$markedCount student(s) already scanned. If you cancel now, this session and all its scans will be discarded — nothing will be saved to the database.'
              : 'This session will be discarded. Nothing will be saved to the database.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.45),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep Session', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.crimsonRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel Session', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      _dbPollTimer?.cancel();

      // Purge the session everywhere: scans are written to the cloud in real
      // time (for live turnout), so a cancelled session must be removed from
      // the cloud too — otherwise students see a phantom class forever.
      try {
        await ApiService.instance.deleteSubjectSessions(widget.subject.id, _sessionId);
      } catch (e) {
        debugPrint('Cloud cancel-purge skipped: $e');
      }
      try {
        final db = await DatabaseHelper.instance.database;
        await db.delete('attendance_records', where: 'session_id = ?', whereArgs: [_sessionId]);
        await db.delete('attendance_sessions', where: 'id = ?', whereArgs: [_sessionId]);
      } catch (_) {}

      if (mounted) {
        _allowPop = true;
        Navigator.pop(context, false); // discard — nothing was saved
      }
    }
  }

  Widget _buildCancelSessionButton() {
    return PressableScale(
      onTap: _cancelSession,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.pillRadius,
          border: Border.all(color: AppTheme.crimsonRoseBorder, width: 1.3),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.xCircle, size: 18, color: AppTheme.crimsonRose),
            SizedBox(width: 9),
            Text(
              'Cancel Session',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppTheme.crimsonRose,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTurnoutCard(int presentCount, int totalCount) {
    final double turnoutPct = totalCount > 0 ? (presentCount / totalCount).clamp(0.0, 1.0) : 0.0;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.borderLight, width: 1.0),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Live breathing dot
              PulseGlow(
                glowColor: AppTheme.emeraldGreen,
                minRadius: 3,
                maxRadius: 8,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(color: AppTheme.emeraldGreen, shape: BoxShape.circle),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Live Turnout',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
              ),
              const Spacer(),
              AnimatedCounter(
                value: turnoutPct * 100,
                suffix: '%',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: turnoutPct >= 0.75 ? AppTheme.emeraldGreen : AppTheme.royalNavy,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedProgressBar(
            value: turnoutPct.clamp(0.0, 1.0),
            height: 10,
            color: AppTheme.emeraldGreen,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              Column(
                children: [
                  Text('Enrolled', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  AnimatedCounter(
                    value: totalCount,
                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                  ),
                ],
              ),
              Container(width: 1, height: 36, color: AppTheme.borderLight),
              Column(
                children: [
                  Text('Present', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  AnimatedCounter(
                    value: presentCount,
                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.emeraldGreen),
                  ),
                ],
              ),
              Container(width: 1, height: 36, color: AppTheme.borderLight),
              Column(
                children: [
                  Text('Absent', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
                  const SizedBox(height: 2),
                  AnimatedCounter(
                    value: (totalCount - presentCount).clamp(0, totalCount),
                    style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.crimsonRose),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
