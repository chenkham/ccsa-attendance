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
import '../../widgets/custom_cards.dart';
import '../../widgets/dynamic_qr_display.dart';
import '../../widgets/marquee_text.dart';
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
  final Set<String> _presentStudentIds = {};
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

    // Poll local database every 1.5 seconds for student check-ins
    _dbPollTimer = Timer.periodic(const Duration(milliseconds: 1500), (_) {
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
      try {
        list = await DatabaseHelper.instance.getStudentsForSubject(widget.subject.id);
      } catch (_) {}

      if (list.isEmpty) {
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
    final Set<String> newPresentIds = {};

    try {
      final db = await DatabaseHelper.instance.database;
      final records = await db.query(
        'attendance_records',
        where: 'session_id = ?',
        whereArgs: [_sessionId],
      );
      for (final r in records) {
        newPresentIds.add(r['student_id'] as String);
      }
    } catch (_) {}

    // Poll live student scans from Hostinger MySQL
    try {
      final cloudLiveIds = await ApiService.instance.getSessionTurnoutLive(_sessionId);
      newPresentIds.addAll(cloudLiveIds);
    } catch (_) {}

    if (mounted && newPresentIds.isNotEmpty) {
      if (newPresentIds.length != _presentStudentIds.length) {
        AppTheme.triggerLightHaptic();
      }
      setState(() {
        _presentStudentIds.addAll(newPresentIds);
      });
    }
  }

  Future<void> _markStudentPresentManually(Student student) async {
    if (_presentStudentIds.contains(student.id)) return;

    AppTheme.triggerSuccessHaptic();
    setState(() {
      _presentStudentIds.add(student.id);
    });

    final record = AttendanceRecord(
      id: const Uuid().v4(),
      sessionId: _sessionId,
      studentId: student.id,
      studentRollNo: student.classRollNo,
      studentName: student.name,
      status: 'present',
      markedBy: 'manual_teacher',
    );

    final db = await DatabaseHelper.instance.database;
    await db.insert('attendance_records', record.toMap());

    // Also push manual mark to Cloud
    ApiService.instance.recordStudentAttendanceLive(
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
  }

  void _showManualAttendanceDialog() {
    AppTheme.triggerLightHaptic();
    String search = '';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
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
                      final isMarked = _presentStudentIds.contains(s.id);
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
    final totalTurnout = _presentStudentIds.length;
    final totalStudents = _enrolledStudents.length;

    final session = AttendanceSession(
      id: _sessionId,
      subjectId: widget.subject.id,
      subjectCode: widget.subject.code,
      subjectName: widget.subject.name,
      teacherEmail: user?.email ?? 'faculty@ccsa.du.ac.in',
      sessionDate: DateTime.now(),
      totalPresent: totalTurnout,
      totalEnrolled: totalStudents,
      isLab: _isLab,
    );

    final List<AttendanceRecord> records = [];

    for (final id in _presentStudentIds) {
      final std = _enrolledStudents.firstWhere((s) => s.id == id, orElse: () => Student(id: id, name: 'Student', classRollNo: '', duExamRollNo: '', email: '', course: '', semester: 1));
      records.add(AttendanceRecord(
        id: const Uuid().v4(),
        sessionId: _sessionId,
        studentId: id,
        studentRollNo: std.classRollNo,
        studentName: std.name,
        status: 'present',
        markedBy: 'totp_qr',
      ));
    }

    for (final student in _enrolledStudents) {
      if (!_presentStudentIds.contains(student.id)) {
        records.add(AttendanceRecord(
          id: const Uuid().v4(),
          sessionId: _sessionId,
          studentId: student.id,
          studentRollNo: student.classRollNo,
          studentName: student.name,
          status: 'absent',
          markedBy: 'system',
        ));
      }
    }

    try {
      await DatabaseHelper.instance.insertAttendanceSession(session, records);
    } catch (_) {}

    // Sync session and records to Hostinger MySQL Database (Item 3)
    try {
      await ApiService.instance.syncAttendanceSession(session, records);
    } catch (e) {
      debugPrint('Sync attendance session cloud error: $e');
    }

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
                Navigator.pop(context, true);
              },
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalNavy, shape: RoundedRectangleBorder(borderRadius: AppTheme.pillRadius)),
              onPressed: () {
                Navigator.pop(ctx);
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
    final presentCount = _presentStudentIds.length;
    final totalCount = _enrolledStudents.length;
    final isWide = Responsive.isWide(context);

    // Full Screen QR Presentation Mode
    if (_isFullScreen) {
      return Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.subject.name,
                      style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Present: $presentCount / $totalCount (${totalCount > 0 ? ((presentCount / totalCount) * 100).toStringAsFixed(0) : 0}%)',
                      style: GoogleFonts.inter(fontSize: 15, color: AppTheme.emeraldGreen, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 28),
                    DynamicQrDisplay(
                      subjectId: widget.subject.id,
                      sessionId: _sessionId,
                      size: isWide ? 340 : 280,
                      isBigScreen: true,
                      geofenceEnabled: _geofenceEnabled,
                      targetLat: _targetLat,
                      targetLng: _targetLng,
                      radiusMeters: _radiusMeters,
                    ),
                  ],
                ),
              ),
              Positioned(
                top: 16,
                right: 16,
                child: IconButton(
                  icon: const Icon(LucideIcons.x, color: Colors.white, size: 28),
                  onPressed: () => setState(() => _isFullScreen = false),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
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
          ? const Center(child: CircularProgressIndicator(color: AppTheme.royalNavy))
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
                          const SizedBox(height: 20),
                        ],
                      ),
                    ),
            ),
    );
  }

  Widget _buildTurnoutCard(int presentCount, int totalCount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.borderLight, width: 1.0),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Column(
            children: [
              Text('Enrolled', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text('$totalCount', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.royalNavy)),
            ],
          ),
          Container(width: 1, height: 36, color: AppTheme.borderLight),
          Column(
            children: [
              Text('Present', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text('$presentCount', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.emeraldGreen)),
            ],
          ),
          Container(width: 1, height: 36, color: AppTheme.borderLight),
          Column(
            children: [
              Text('Turnout', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
              const SizedBox(height: 2),
              Text(
                '${totalCount > 0 ? ((presentCount / totalCount) * 100).toStringAsFixed(0) : 0}%',
                style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
