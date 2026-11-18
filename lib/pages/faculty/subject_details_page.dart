import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../db/database_helper.dart';
import '../../models/student.dart';
import '../../models/subject.dart';
import '../../models/attendance_session.dart';
import 'package:uuid/uuid.dart';
import '../../services/auth_service.dart';
import '../../services/api_service.dart';
import '../../services/csv_export_service.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/marquee_text.dart';
import '../../widgets/custom_cards.dart';
import '../../widgets/doodle_art.dart';
import '../../widgets/micro_interactions.dart';
import '../../widgets/student_attendance_dialog.dart';
import 'dynamic_qr_session_page.dart';

class SubjectDetailsPage extends StatefulWidget {
  final Subject subject;

  const SubjectDetailsPage({super.key, required this.subject});

  @override
  State<SubjectDetailsPage> createState() => _SubjectDetailsPageState();
}

class _SubjectDetailsPageState extends State<SubjectDetailsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Student> _students = [];
  List<AttendanceSession> _sessions = [];
  Map<String, Map<String, dynamic>> _studentStats = {};
  bool _isLoading = true;

  String _rosterSearch = '';
  Subject? _currentSubject;

  Subject get _activeSubject => _currentSubject ?? widget.subject;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    List<Student> stds = [];
    List<AttendanceSession> sess = [];
    Map<String, Map<String, dynamic>> stats = {};

    try {
      // 1. Fetch live authoritative state from Cloud MySQL (parallel)
      final results = await Future.wait([
        ApiService.instance.getFacultySessions(subjectId: widget.subject.id),
        ApiService.instance.getRegisteredStudents(
          course: widget.subject.course,
          semester: widget.subject.semester,
        ),
      ]);
      sess = results[0] as List<AttendanceSession>;
      final cloudStds = results[1] as List<Student>;

      if (cloudStds.isNotEmpty) {
        final enrolledSet = widget.subject.enrolledStudentIds.toSet();
        if (enrolledSet.isNotEmpty) {
          stds = cloudStds.where((s) => enrolledSet.contains(s.id)).toList();
        }
        if (stds.isEmpty) stds = cloudStds;
      }

      // Reconcile local SQLite cache: prune deleted sessions
      try {
        final db = await DatabaseHelper.instance.database;
        final localSessions = await DatabaseHelper.instance.getSessionsForSubject(widget.subject.id);
        final cloudSessionIds = sess.map((s) => s.id).toSet();
        for (var localS in localSessions) {
          if (!cloudSessionIds.contains(localS.id)) {
            await db.delete('attendance_records', where: 'session_id = ?', whereArgs: [localS.id]);
            await db.delete('attendance_sessions', where: 'id = ?', whereArgs: [localS.id]);
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Subject details offline fallback: $e');
      try {
        stds = await DatabaseHelper.instance.getStudentsForSubject(widget.subject.id);
        sess = await DatabaseHelper.instance.getSessionsForSubject(widget.subject.id);
      } catch (_) {}
    }

    // Calculate subject attendance statistics
    for (var s in stds) {
      int totalHeld = sess.length;
      int attended = 0;
      for (var session in sess) {
        final isPresent = session.records.any((r) {
          if (!r.isPresent) return false;
          if (r.studentId.isNotEmpty && r.studentId == s.id) return true;
          if (r.studentRollNo.isNotEmpty && r.studentRollNo == s.classRollNo) return true;
          if (r.studentName.isNotEmpty && r.studentName.toLowerCase() == s.name.toLowerCase()) return true;
          if (r.studentId.isNotEmpty && s.email != null && s.email!.isNotEmpty && r.studentId.toLowerCase() == s.email!.toLowerCase()) return true;
          if (r.studentId.isNotEmpty && s.duExamRollNo.isNotEmpty && r.studentId.toLowerCase() == s.duExamRollNo.toLowerCase()) return true;
          if (r.studentRollNo.isNotEmpty && s.duExamRollNo.isNotEmpty && r.studentRollNo.toLowerCase() == s.duExamRollNo.toLowerCase()) return true;
          return false;
        });
        if (isPresent) attended++;
      }
      final double percentage = totalHeld > 0 ? (attended / totalHeld) * 100.0 : 100.0;
      stats[s.id] = {
        'total': totalHeld,
        'attended': attended,
        'missed': totalHeld - attended,
        'percentage': percentage,
      };
    }

    if (mounted) {
      setState(() {
        _students = stds;
        _sessions = sess;
        _studentStats = stats;
        _isLoading = false;
      });
    }
  }

  void _exportCsv() {
    CsvExportService.instance.showExportDialog(
      context: context,
      subject: widget.subject,
    );
  }

  // Add / Enroll Absent Student who registered later (Item 16)
  Future<void> _openAddStudentDialog() async {
    AppTheme.triggerLightHaptic();

    // 1. Fetch live registered students from Hostinger MySQL
    final onlineStudents = await ApiService.instance.getRegisteredStudents(
      course: widget.subject.course,
      semester: widget.subject.semester,
    );

    for (final std in onlineStudents) {
      await DatabaseHelper.instance.insertStudent(std);
    }

    final allCourseStudents = await DatabaseHelper.instance.getStudentsByCourseAndSemester(
      widget.subject.course,
      widget.subject.semester,
    );

    final enrolledIds = _students.map((s) => s.id).toSet();
    final notEnrolledStudents = allCourseStudents.where((s) => !enrolledIds.contains(s.id)).toList();

    if (!mounted) return;

    if (notEnrolledStudents.isEmpty) {
      AppTheme.showSnackBar(
        context,
        'All registered ${widget.subject.course} ${widget.subject.semesterDisplay} students are already enrolled!',
        isSuccess: true,
      );
      return;
    }

    final Set<String> newlySelectedIds = {};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.royalNavy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.userPlus, color: AppTheme.royalNavy, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add Student to Subject',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 380,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select students to enroll in ${widget.subject.code}:',
                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 250,
                    child: ListView.separated(
                      itemCount: notEnrolledStudents.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
                      itemBuilder: (context, index) {
                        final std = notEnrolledStudents[index];
                        final isChecked = newlySelectedIds.contains(std.id);
                        final rollDisplay = std.classRollNo.isNotEmpty ? 'Roll ${std.classRollNo}' : 'Roll ${index + 1}';

                        return CheckboxListTile(
                          value: isChecked,
                          activeColor: AppTheme.royalNavy,
                          contentPadding: EdgeInsets.zero,
                          title: Text('$rollDisplay • ${std.name}', style: GoogleFonts.inter(fontWeight: FontWeight.w600, fontSize: 13.5)),
                          onChanged: (val) {
                            setDialogState(() {
                              if (val == true) {
                                newlySelectedIds.add(std.id);
                              } else {
                                newlySelectedIds.remove(std.id);
                              }
                            });
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: newlySelectedIds.isEmpty
                    ? null
                    : () async {
                        final messenger = ScaffoldMessenger.of(context);
                        final nav = Navigator.of(ctx);
                        final db = await DatabaseHelper.instance.database;
                        for (final id in newlySelectedIds) {
                          await db.insert('subject_students', {
                            'subject_id': widget.subject.id,
                            'student_id': id,
                          });
                        }

                        // Sync updated enrollment to Hostinger MySQL
                        final allEnrolled = [...widget.subject.enrolledStudentIds, ...newlySelectedIds];
                        final updatedSub = Subject(
                          id: widget.subject.id,
                          name: widget.subject.name,
                          code: widget.subject.code,
                          professorName: widget.subject.professorName,
                          course: widget.subject.course,
                          semester: widget.subject.semester,
                          batchType: widget.subject.batchType,
                          teacherEmail: widget.subject.teacherEmail,
                          enrolledStudentIds: allEnrolled,
                          geofenceEnabled: widget.subject.geofenceEnabled,
                          latitude: widget.subject.latitude,
                          longitude: widget.subject.longitude,
                          radiusMeters: widget.subject.radiusMeters,
                          createdAt: widget.subject.createdAt,
                        );
                        ApiService.instance.syncSubject(updatedSub);

                        nav.pop();
                        AppTheme.triggerSuccessHaptic();
                        _loadData();
                        messenger.showSnackBar(
                          SnackBar(
                            content: Text('${newlySelectedIds.length} student(s) added successfully!'),
                            backgroundColor: AppTheme.emeraldGreen,
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                child: Text('Enroll (${newlySelectedIds.length})'),
              ),
            ],
          );
        },
      ),
    );
  }

  // Import / Baseline Attendance from Physical Register
  // Idempotent: baseline sessions use deterministic ids (baseline_<subjectId>_<n>)
  // so re-importing replaces the previous baseline in cloud + local instead of
  // duplicating history. Live QR sessions are never touched.
  Future<void> _openPhysicalRegisterBaselineDialog() async {
    AppTheme.triggerLightHaptic();
    if (_students.isEmpty) {
      AppTheme.showSnackBar(context, 'No students enrolled in this subject yet.', isError: true);
      return;
    }

    final totalClassesCtrl = TextEditingController(text: '10');
    final Map<String, TextEditingController> studentCounts = {};
    for (final s in _students) {
      studentCounts[s.id] = TextEditingController(text: '10');
    }

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          int totalHeld = int.tryParse(totalClassesCtrl.text) ?? 10;
          if (totalHeld < 1) totalHeld = 1;

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: AppTheme.royalNavy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(LucideIcons.bookOpen, color: AppTheme.royalNavy, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import from Physical Register',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        'Safely integrate previous offline attendance',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 440,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Total Classes Held on Register',
                                  style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.royalNavy),
                                ),
                                Text(
                                  'Number of past offline lectures conducted',
                                  style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 70,
                            child: TextField(
                              controller: totalClassesCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
                              decoration: InputDecoration(
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onChanged: (val) {
                                setDialogState(() {});
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Per-Student Attendance:',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Late-joiner shortcut: attended 0 of the past classes
                            TextButton.icon(
                              icon: const Icon(LucideIcons.userX, size: 14),
                              label: const Text('Joined Late', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onPressed: () {
                                setDialogState(() {
                                  for (final ctrl in studentCounts.values) {
                                    ctrl.text = '0';
                                  }
                                });
                              },
                            ),
                            TextButton.icon(
                              icon: const Icon(LucideIcons.checkCheck, size: 14),
                              label: const Text('All to Max', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                              onPressed: () {
                                setDialogState(() {
                                  for (final ctrl in studentCounts.values) {
                                    ctrl.text = '$totalHeld';
                                  }
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderSubtle),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _students.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
                        itemBuilder: (context, index) {
                          final s = _students[index];
                          final ctrl = studentCounts[s.id]!;
                          final rollDisplay = s.classRollNo.isNotEmpty ? 'Roll ${s.classRollNo}' : 'Roll ${index + 1}';
                          final attended = (int.tryParse(ctrl.text) ?? 0).clamp(0, totalHeld);
                          final pct = totalHeld > 0 ? (attended / totalHeld) * 100 : 0.0;

                          final pctColor = pct >= 80 ? const Color(0xFF047857) : AppTheme.crimsonRose;

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 15,
                                  backgroundColor: AppTheme.royalNavy.withOpacity(0.08),
                                  child: Text(
                                    s.classRollNo.isNotEmpty ? s.classRollNo : '${index + 1}',
                                    style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                                      ),
                                      RichText(
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        text: TextSpan(
                                          style: DefaultTextStyle.of(context).style,
                                          children: [
                                            TextSpan(
                                              text: rollDisplay,
                                              style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textSecondary),
                                            ),
                                            TextSpan(
                                              text: '  •  ',
                                              style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textMuted),
                                            ),
                                            TextSpan(
                                              text: '$attended/$totalHeld (${pct.toStringAsFixed(0)}%)',
                                              style: GoogleFonts.inter(fontSize: 10.5, fontWeight: FontWeight.w800, color: pctColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Compact stepper: [-] count [+]
                                Container(
                                  decoration: BoxDecoration(
                                    border: Border.all(color: AppTheme.borderLight),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          final current = int.tryParse(ctrl.text) ?? 0;
                                          if (current > 0) {
                                            ctrl.text = '${current - 1}';
                                            setDialogState(() {});
                                          }
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                          child: Icon(LucideIcons.minus, size: 14, color: AppTheme.crimsonRose),
                                        ),
                                      ),
                                      SizedBox(
                                        width: 26,
                                        child: Text(
                                          '$attended',
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppTheme.royalNavy),
                                        ),
                                      ),
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          final current = int.tryParse(ctrl.text) ?? 0;
                                          if (current < totalHeld) {
                                            ctrl.text = '${current + 1}';
                                            setDialogState(() {});
                                          }
                                        },
                                        child: const Padding(
                                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                                          child: Icon(LucideIcons.plus, size: 14, color: Color(0xFF047857)),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);
                  final int nClasses = int.tryParse(totalClassesCtrl.text) ?? 0;
                  if (nClasses <= 0 || nClasses > 400) {
                    messenger.showSnackBar(const SnackBar(content: Text('Please enter a valid number of classes (1–400).')));
                    return;
                  }

                  nav.pop();
                  setState(() => _isLoading = true);

                  final user = AuthService.instance.currentUser;
                  final now = DateTime.now();
                  // Deterministic prefix so re-imports replace (never duplicate)
                  final baselinePrefix = 'baseline_${widget.subject.id}_';

                  // 1. Remove previous baseline sessions (cloud first, then local cache)
                  try {
                    await ApiService.instance.deleteSubjectSessions(widget.subject.id, baselinePrefix);
                  } catch (e) {
                    debugPrint('Cloud baseline cleanup skipped: $e');
                  }
                  try {
                    final db = await DatabaseHelper.instance.database;
                    final oldBaselineSessions = await db.rawQuery(
                      "SELECT id FROM attendance_sessions WHERE subject_id = ? AND id LIKE ?",
                      [widget.subject.id, '$baselinePrefix%'],
                    );
                    for (final row in oldBaselineSessions) {
                      final sid = row['id'] as String;
                      await db.delete('attendance_records', where: 'session_id = ?', whereArgs: [sid]);
                      await db.delete('attendance_sessions', where: 'id = ?', whereArgs: [sid]);
                    }
                  } catch (_) {}

                  // 2. Create N past register sessions with deterministic ids
                  for (int k = 1; k <= nClasses; k++) {
                    final sessionId = '$baselinePrefix$k';
                    final sessionDate = now.subtract(Duration(days: (nClasses - k + 1)));

                    int presentCount = 0;
                    final List<AttendanceRecord> records = [];

                    for (final s in _students) {
                      final attendedCount = (int.tryParse(studentCounts[s.id]?.text ?? '0') ?? 0).clamp(0, nClasses);
                      final isPresent = attendedCount >= k;
                      if (isPresent) presentCount++;

                      records.add(AttendanceRecord(
                        id: const Uuid().v4(),
                        sessionId: sessionId,
                        studentId: s.id,
                        studentRollNo: s.classRollNo,
                        studentName: s.name,
                        status: isPresent ? 'present' : 'absent',
                        markedBy: 'physical_register',
                        createdAt: sessionDate,
                      ));
                    }

                    final session = AttendanceSession(
                      id: sessionId,
                      subjectId: widget.subject.id,
                      subjectCode: widget.subject.code,
                      subjectName: widget.subject.name,
                      teacherEmail: user?.email ?? widget.subject.teacherEmail,
                      sessionDate: sessionDate,
                      totalPresent: presentCount,
                      totalEnrolled: _students.length,
                      isLab: false,
                    );

                    await DatabaseHelper.instance.insertAttendanceSession(session, records);
                    await ApiService.instance.syncAttendanceSession(session, records);
                  }

                  AppTheme.triggerSuccessHaptic();
                  await _loadData();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Imported $nClasses physical register lectures — previous attendance is now safely in the database.'),
                      backgroundColor: AppTheme.emeraldGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Import to Database', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  // View Full Session Attendance Sheet + EDIT mode:
  // teacher can flip Present/Absent per student, save syncs to the cloud
  // database (record ids preserved → upsert, no duplicates) and local cache.
  void _showSessionDetailChart(AttendanceSession session) {
    AppTheme.triggerLightHaptic();
    final dateFormatted = DateFormat('EEE, dd MMM yyyy • hh:mm a').format(session.sessionDate);

    // Edit-mode state (lives outside StatefulBuilder so it survives rebuilds)
    bool editMode = false;
    bool saving = false;
    bool editsInitialized = false;
    final edits = <String, Map<String, dynamic>>{};
    final originals = <String, Map<String, dynamic>>{};

    Future<Map<String, dynamic>> fetchDetails() async {
      // 1. Try fetching from Cloud
      try {
        final cloudData = await ApiService.instance.getSessionDetails(session.id);
        if (cloudData != null && cloudData['success'] == true && cloudData['records'] is List) {
          final rawList = cloudData['records'] as List;
          final list = rawList.map((r) => Map<String, dynamic>.from(r as Map)).toList();
          final totPresent = cloudData['total_present'] is int
              ? cloudData['total_present'] as int
              : list.where((r) => (r['status'] as String?)?.toLowerCase() == 'present').length;
          final totEnrolled = cloudData['total_enrolled'] is int
              ? cloudData['total_enrolled'] as int
              : list.length;
          final pct = totEnrolled > 0 ? (totPresent / totEnrolled) * 100.0 : 100.0;

          return {
            'records': list,
            'total_present': totPresent,
            'total_enrolled': totEnrolled,
            'percentage': pct,
          };
        }
      } catch (e) {
        debugPrint('Error fetching session details from cloud: $e');
      }

      // 2. Fallback to local SQLite
      List<Map<String, dynamic>> records = [];
      try {
        final db = await DatabaseHelper.instance.database;
        records = await db.query(
          'attendance_records',
          where: 'session_id = ?',
          whereArgs: [session.id],
        );
      } catch (_) {}

      final List<Map<String, dynamic>> unified = [];
      int presentCount = 0;

      if (_students.isNotEmpty) {
        for (final std in _students) {
          final isPresent = records.any((r) {
            final sid = r['student_id'] as String? ?? '';
            final sroll = r['student_roll_no'] as String? ?? '';
            final sname = (r['student_name'] as String? ?? '').toLowerCase();
            return (sid.isNotEmpty && sid == std.id) ||
                (sroll.isNotEmpty && sroll == std.classRollNo) ||
                (sname.isNotEmpty && sname == std.name.toLowerCase()) ||
                (std.email != null && std.email!.isNotEmpty && sid.toLowerCase() == std.email!.toLowerCase()) ||
                (std.duExamRollNo.isNotEmpty && sid.toLowerCase() == std.duExamRollNo.toLowerCase()) ||
                (std.duExamRollNo.isNotEmpty && sroll.toLowerCase() == std.duExamRollNo.toLowerCase());
          });

          if (isPresent) presentCount++;

          unified.add({
            'id': std.id,
            'student_name': std.name,
            'student_roll_no': std.classRollNo,
            'du_exam_roll_no': std.duExamRollNo,
            'status': isPresent ? 'present' : 'absent',
            'marked_by': 'system',
          });
        }
      } else {
        for (final r in records) {
          final isPresent = (r['status'] as String?)?.toLowerCase() == 'present';
          if (isPresent) presentCount++;
          unified.add({
            'id': r['student_id'],
            'student_name': r['student_name'] ?? 'Student',
            'student_roll_no': r['student_roll_no'] ?? '',
            'du_exam_roll_no': '',
            'status': isPresent ? 'present' : 'absent',
            'marked_by': r['marked_by'] ?? 'system',
          });
        }
      }

      final totEnrolled = unified.length;
      final pct = totEnrolled > 0 ? (presentCount / totEnrolled) * 100.0 : 100.0;

      return {
        'records': unified,
        'total_present': presentCount,
        'total_enrolled': totEnrolled,
        'percentage': pct,
      };
    }

    /// Push the edited statuses to the cloud + local database.
    Future<void> saveEdits(StateSetter setSheetState) async {
      setSheetState(() => saving = true);

      final recordIds = <String>{};
      final records = <AttendanceRecord>[];
      int presentCount = 0;

      edits.forEach((sid, e) {
        final status = (e['status'] as String? ?? 'absent');
        if (status == 'present') presentCount++;
        var rid = (e['recordId'] as String? ?? '');
        if (rid.isEmpty || rid.startsWith('rec_') || !recordIds.add(rid)) {
          rid = const Uuid().v4();
        }
        records.add(AttendanceRecord(
          id: rid,
          sessionId: session.id,
          studentId: sid,
          studentRollNo: (e['roll'] ?? '') as String,
          studentName: (e['name'] ?? 'Student') as String,
          status: status,
          markedBy: (e['markedBy'] ?? 'manual_teacher') as String,
          createdAt: session.sessionDate,
        ));
      });

      final updated = AttendanceSession(
        id: session.id,
        subjectId: session.subjectId,
        subjectCode: session.subjectCode,
        subjectName: session.subjectName,
        sessionDate: session.sessionDate,
        isLab: session.isLab,
        teacherEmail: session.teacherEmail,
        totalPresent: presentCount,
        totalEnrolled: records.length,
      );

      bool cloudOk = false;
      try {
        cloudOk = await ApiService.instance.syncAttendanceSession(updated, records);
      } catch (e) {
        debugPrint('Cloud attendance edit failed: $e');
      }

      // Local cache: replace records + session row
      try {
        final db = await DatabaseHelper.instance.database;
        await db.delete('attendance_records', where: 'session_id = ?', whereArgs: [session.id]);
        await db.delete('attendance_sessions', where: 'id = ?', whereArgs: [session.id]);
        await DatabaseHelper.instance.insertAttendanceSession(updated, records);
      } catch (e) {
        debugPrint('Local attendance edit cache failed: $e');
      }

      if (!mounted) return;
      Navigator.pop(context);
      if (cloudOk) {
        AppTheme.triggerSuccessHaptic();
        AppTheme.showSnackBar(context, 'Attendance updated & synced to the database.', isSuccess: true);
      } else {
        AppTheme.showSnackBar(context, 'Saved on this device, but cloud sync failed — check your connection.', isError: true);
      }
      await _loadData();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgLight,
      builder: (bCtx) {
        final detailsFuture = fetchDetails();
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              child: FutureBuilder<Map<String, dynamic>>(
                future: detailsFuture,
                builder: (context, snapshot) {
                  final isLoading = snapshot.connectionState == ConnectionState.waiting;
                  final data = snapshot.data;
                  final records = (data?['records'] as List?) ?? [];
                  final totalPresent = (data?['total_present'] as int?) ?? session.totalPresent;
                  final totalEnrolled = (data?['total_enrolled'] as int?) ?? session.totalEnrolled;
                  final percentage = (data?['percentage'] as double?) ?? session.attendancePercentage;
                  final totalAbsent = (totalEnrolled - totalPresent).clamp(0, totalEnrolled);

                  // Seed the editable map once records arrive
                  if (!editsInitialized && !isLoading && records.isNotEmpty) {
                    editsInitialized = true;
                    for (final recRaw in records) {
                      final rec = Map<String, dynamic>.from(recRaw as Map);
                      final sid = (rec['student_id'] ?? rec['id'] ?? '').toString();
                      if (sid.isEmpty) continue;
                      final entry = {
                        'recordId': (rec['id'] ?? '').toString(),
                        'name': (rec['student_name'] ?? 'Student').toString(),
                        'roll': (rec['student_roll_no'] ?? '').toString(),
                        'status': ((rec['status'] ?? 'absent') as String).toLowerCase() == 'present' ? 'present' : 'absent',
                        'markedBy': (rec['marked_by'] ?? 'system').toString(),
                      };
                      edits[sid] = entry;
                      originals[sid] = Map<String, dynamic>.from(entry);
                    }
                  }

                  int livePresent = 0;
                  edits.forEach((_, e) {
                    if (e['status'] == 'present') livePresent++;
                  });
                  final liveAbsent = edits.length - livePresent;

                  final sortedEdits = edits.entries.toList()
                    ..sort((a, b) {
                      int num(String v) => int.tryParse(v.replaceAll(RegExp(r'[^0-9]'), '')) ?? 9999;
                      final an = num(a.value['roll'] as String? ?? '');
                      final bn = num(b.value['roll'] as String? ?? '');
                      if (an != 9999 && bn != 9999 && an != bn) return an.compareTo(bn);
                      return (a.value['name'] as String? ?? '').compareTo(b.value['name'] as String? ?? '');
                    });

                  return Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.borderLight,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Sheet Header + Edit toggle
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Session Attendance Sheet',
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.royalNavy),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    dateFormatted,
                                    style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                            // Edit / Done-editing toggle
                            if (!isLoading && records.isNotEmpty && !saving)
                              GestureDetector(
                                onTap: () {
                                  AppTheme.triggerLightHaptic();
                                  setSheetState(() {
                                    if (editMode) {
                                      // discard pending changes
                                      edits.forEach((sid, e) {
                                        e['status'] = originals[sid]?['status'] ?? e['status'];
                                      });
                                    }
                                    editMode = !editMode;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: AppTheme.motionFast,
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: editMode ? AppTheme.emeraldGreenBg : AppTheme.googleSky.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: editMode ? AppTheme.emeraldGreenBorder : AppTheme.googleBlue.withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        editMode ? LucideIcons.check : LucideIcons.pencil,
                                        size: 14,
                                        color: editMode ? const Color(0xFF047857) : AppTheme.googleBlue,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        editMode ? 'Editing' : 'Edit',
                                        style: GoogleFonts.inter(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w800,
                                          color: editMode ? const Color(0xFF047857) : AppTheme.googleBlue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            IconButton(
                              icon: const Icon(LucideIcons.x, size: 20),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Summary pill
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppTheme.bgLight,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.borderLight),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              Row(
                                children: [
                                  const Icon(LucideIcons.checkCircle2, size: 16, color: Color(0xFF047857)),
                                  const SizedBox(width: 6),
                                  Text(
                                    editMode ? 'Present: $livePresent' : 'Present: $totalPresent',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF047857)),
                                  ),
                                ],
                              ),
                              Container(width: 1, height: 24, color: AppTheme.borderLight),
                              Row(
                                children: [
                                  const Icon(LucideIcons.xCircle, size: 16, color: AppTheme.crimsonRose),
                                  const SizedBox(width: 6),
                                  Text(
                                    editMode ? 'Absent: $liveAbsent' : 'Absent: $totalAbsent',
                                    style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.crimsonRose),
                                  ),
                                ],
                              ),
                              Container(width: 1, height: 24, color: AppTheme.borderLight),
                              Text(
                                '${percentage.toStringAsFixed(1)}%',
                                style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),

                      // Student list
                      Expanded(
                        child: isLoading
                            ? const Center(child: BrandLoader(size: 40))
                            : records.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const DoodleEmptyArt(scene: DoodleScene.clipboardCheck, size: 110),
                                        const SizedBox(height: 8),
                                        Text(
                                          'No attendance records found for this session.',
                                          style: GoogleFonts.inter(color: AppTheme.textSecondary),
                                        ),
                                      ],
                                    ),
                                  )
                                : editMode
                                    ? ListView.separated(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                        itemCount: sortedEdits.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
                                        itemBuilder: (context, index) {
                                          final entry = sortedEdits[index];
                                          final e = entry.value;
                                          final isPresent = e['status'] == 'present';
                                          final rollNo = (e['roll'] as String? ?? '').isNotEmpty ? e['roll'] as String : '${index + 1}';

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 17,
                                                  backgroundColor: isPresent ? AppTheme.emeraldGreenBg : AppTheme.crimsonRoseBg,
                                                  child: Text(
                                                    rollNo,
                                                    style: TextStyle(
                                                      fontWeight: FontWeight.w800,
                                                      fontSize: 11.5,
                                                      color: isPresent ? const Color(0xFF047857) : AppTheme.crimsonRose,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    e['name'] as String? ?? 'Student',
                                                    maxLines: 1,
                                                    overflow: TextOverflow.ellipsis,
                                                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
                                                  ),
                                                ),
                                                const SizedBox(width: 6),
                                                _statusToggleChip(
                                                  label: 'Present',
                                                  selected: isPresent,
                                                  color: AppTheme.emeraldGreen,
                                                  onTap: () => setSheetState(() => e['status'] = 'present'),
                                                ),
                                                const SizedBox(width: 6),
                                                _statusToggleChip(
                                                  label: 'Absent',
                                                  selected: !isPresent,
                                                  color: AppTheme.crimsonRose,
                                                  onTap: () => setSheetState(() => e['status'] = 'absent'),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      )
                                    : ListView.separated(
                                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                        itemCount: records.length,
                                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
                                        itemBuilder: (context, index) {
                                          final rec = records[index];
                                          final isPresent = (rec['status'] as String?)?.toLowerCase() == 'present';
                                          final rollNo = (rec['student_roll_no'] as String? ?? '').isNotEmpty
                                              ? rec['student_roll_no'] as String
                                              : '${index + 1}';
                                          final name = (rec['student_name'] as String? ?? '').isNotEmpty
                                              ? rec['student_name'] as String
                                              : 'Student';

                                          return ListTile(
                                            contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                            leading: CircleAvatar(
                                              radius: 18,
                                              backgroundColor: isPresent ? AppTheme.emeraldGreenBg : AppTheme.crimsonRoseBg,
                                              child: Text(
                                                rollNo,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 12,
                                                  color: isPresent ? const Color(0xFF047857) : AppTheme.crimsonRose,
                                                ),
                                              ),
                                            ),
                                            title: Text(
                                              name,
                                              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5),
                                            ),
                                            subtitle: Text('Roll $rollNo', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
                                            trailing: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isPresent ? AppTheme.emeraldGreenBg : AppTheme.crimsonRoseBg,
                                                borderRadius: BorderRadius.circular(16),
                                                border: Border.all(color: isPresent ? AppTheme.emeraldGreenBorder : AppTheme.crimsonRoseBorder),
                                              ),
                                              child: Text(
                                                isPresent ? 'Present' : 'Absent',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                  color: isPresent ? const Color(0xFF047857) : AppTheme.crimsonRose,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                      ),

                      // Save bar (edit mode)
                      if (editMode)
                        Container(
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            border: Border(top: BorderSide(color: AppTheme.borderLight)),
                          ),
                          padding: const EdgeInsets.fromLTRB(20, 10, 20, 12),
                          child: SafeArea(
                            top: false,
                            child: Row(
                              children: [
                                TextButton(
                                  onPressed: saving
                                      ? null
                                      : () {
                                          setSheetState(() {
                                            edits.forEach((sid, e) {
                                              e['status'] = originals[sid]?['status'] ?? e['status'];
                                            });
                                            editMode = false;
                                          });
                                        },
                                  child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: PressableScale(
                                    onTap: saving ? null : () => saveEdits(setSheetState),
                                    child: Container(
                                      height: 48,
                                      decoration: BoxDecoration(
                                        gradient: const LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: [AppTheme.royalNavy, Color(0xFF164E7E)],
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: AppTheme.glowShadowNavy,
                                      ),
                                      alignment: Alignment.center,
                                      child: saving
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                                            )
                                          : Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(LucideIcons.save, size: 17, color: Colors.white),
                                                const SizedBox(width: 8),
                                                Text(
                                                  'Save Changes ($livePresent Present)',
                                                  style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5, color: Colors.white),
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  /// Present/Absent toggle chip used by the session edit sheet.
  Widget _statusToggleChip({
    required String label,
    required bool selected,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: () {
        AppTheme.triggerSelectionHaptic();
        onTap();
      },
      child: AnimatedContainer(
        duration: AppTheme.motionFast,
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color, width: 1.3),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 10.5,
            fontWeight: FontWeight.w800,
            color: selected ? Colors.white : color,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalPresentAcrossSessions = 0;
    for (var s in _sessions) {
      totalPresentAcrossSessions += s.totalPresent;
    }
    final avgAttendance = (_sessions.isNotEmpty && _students.isNotEmpty)
        ? (totalPresentAcrossSessions / (_sessions.length * _students.length)) * 100
        : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        backgroundColor: AppTheme.bgLight,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MarqueeText(
              text: widget.subject.name,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            Text(
              widget.subject.code,
              style: GoogleFonts.sourceCodePro(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
            ),
            Text(
              widget.subject.professorName,
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Classroom Geofence Settings',
            icon: Icon(
              LucideIcons.mapPin,
              color: _activeSubject.geofenceEnabled ? AppTheme.emeraldGreen : AppTheme.textMuted,
            ),
            onPressed: _openGeofenceEditor,
          ),
          IconButton(
            tooltip: 'Import Physical Register Attendance',
            icon: const Icon(LucideIcons.bookOpen, color: AppTheme.royalNavy),
            onPressed: _openPhysicalRegisterBaselineDialog,
          ),
          IconButton(
            tooltip: 'Export CSV',
            icon: const Icon(LucideIcons.fileSpreadsheet, color: AppTheme.emeraldGreen),
            onPressed: _exportCsv,
          ),
          const SizedBox(width: 4),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppTheme.royalNavy,
          unselectedLabelColor: AppTheme.textSecondary,
          indicatorColor: AppTheme.royalNavy,
          indicatorWeight: 3,
          dividerColor: Colors.transparent,
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'Enrolled (${_students.length})'),
            Tab(text: 'Past Sessions (${_sessions.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: BrandLoader(message: 'Loading subject…', size: 44))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildRosterTab(avgAttendance),
                _buildSessionsTab(),
              ],
            ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          border: const Border(top: BorderSide(color: AppTheme.borderLight)),
          boxShadow: AppTheme.softShadow,
        ),
        child: SafeArea(
          child: PressableScale(
            onTap: () async {
              final taken = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DynamicQrSessionPage(subject: _activeSubject)),
              );
              if (taken == true) _loadData();
            },
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppTheme.royalNavy, Color(0xFF164E7E)],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: AppTheme.glowShadowNavy,
              ),
              alignment: Alignment.center,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(LucideIcons.qrCode, size: 18, color: Colors.white),
                  const SizedBox(width: 9),
                  Text(
                    'Start Attendance',
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14.5, color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRosterTab(double avgAttendance) {
    final filteredStudents = _students.where((s) {
      final matchesSearch = s.name.toLowerCase().contains(_rosterSearch.toLowerCase()) ||
          s.classRollNo.toLowerCase().contains(_rosterSearch.toLowerCase());
      return matchesSearch;
    }).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Metrics Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppTheme.roundedRadius,
              border: Border.all(color: AppTheme.borderLight, width: 1.2),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatColumn('Enrolled', '${_students.length}', AppTheme.royalNavy),
                Container(width: 1, height: 32, color: AppTheme.borderLight),
                _buildStatColumn('Sessions', '${_sessions.length}', AppTheme.electricTeal),
                Container(width: 1, height: 32, color: AppTheme.borderLight),
                _buildStatColumn('Average %', '${avgAttendance.toStringAsFixed(0)}%', AppTheme.royalNavy),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Search & Add Student Row (Item 16)
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _rosterSearch = v.trim()),
                  decoration: InputDecoration(
                    hintText: 'Search by roll or name...',
                    prefixIcon: const Icon(LucideIcons.search, size: 16, color: AppTheme.textSecondary),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderLight)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppTheme.borderLight)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              PressableScale(
                onTap: _openAddStudentDialog,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppTheme.royalNavy, Color(0xFF164E7E)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: AppTheme.glowShadowNavy,
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.userPlus, size: 15, color: Colors.white),
                      SizedBox(width: 7),
                      Text('Add Student', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          SectionHeader(title: 'Enrolled Students', count: '${filteredStudents.length}'),
          const SizedBox(height: 10),

          if (filteredStudents.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.roundedRadius,
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                children: [
                  const DoodleEmptyArt(scene: DoodleScene.magnifier, size: 110),
                  const SizedBox(height: 8),
                  Text('No students matched your search.', style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filteredStudents.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final std = filteredStudents[index];
                final st = _studentStats[std.id] ?? {'total': 0, 'attended': 0, 'percentage': 0.0};
                final double pct = (st['percentage'] as num?)?.toDouble() ?? 0.0;
                final int attended = (st['attended'] as int?) ?? 0;
                final int total = (st['total'] as int?) ?? 0;

                final rollNo = std.classRollNo.isNotEmpty ? std.classRollNo : '${index + 1}';

                return StaggeredEntrance(
                  index: index.clamp(0, 8),
                  child: PressableScale(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => StudentAttendanceDialog(
                          subject: widget.subject,
                          stats: st,
                        ),
                      );
                    },
                    pressedScale: 0.98,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: AppTheme.roundedRadius,
                        border: Border.all(color: AppTheme.borderLight),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: Row(
                        children: [
                          // Prominent Roll Number Avatar (Item 1)
                          CircleAvatar(
                            radius: 19,
                            backgroundColor: AppTheme.royalNavy.withOpacity(0.08),
                            child: Text(
                              rollNo,
                              style: GoogleFonts.sourceCodePro(fontWeight: FontWeight.w800, fontSize: 12.5, color: AppTheme.royalNavy),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(std.name, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5)),
                                Text('Roll $rollNo', style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary)),
                              ],
                            ),
                          ),
                          // Single Subject Attendance Percentage (Item 4: No NC/DC on single subject)
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                '${pct.toStringAsFixed(1)}%',
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 14,
                                  color: pct >= 80 ? AppTheme.emeraldGreen : AppTheme.crimsonRose,
                                ),
                              ),
                              Text(
                                '$attended / $total classes',
                                style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSessionsTab() {
    // Split register-imported baseline sessions from live QR sessions.
    // Baselines are shown as ONE summary card, never as individual dated cards.
    final baselinePrefix = 'baseline_${widget.subject.id}_';
    final baselineSessions = _sessions.where((s) => s.id.startsWith(baselinePrefix)).toList()
      ..sort((a, b) => a.sessionDate.compareTo(b.sessionDate));
    final liveSessions = _sessions.where((s) => !s.id.startsWith(baselinePrefix)).toList()
      ..sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const DoodleEmptyArt(scene: DoodleScene.qrFrame, size: 140),
            const SizedBox(height: 12),
            Text('No sessions recorded yet.', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            PressableScale(
              onTap: () async {
                final taken = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DynamicQrSessionPage(subject: _activeSubject)),
                );
                if (taken == true) _loadData();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 12),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.royalNavy, Color(0xFF164E7E)],
                  ),
                  borderRadius: AppTheme.pillRadius,
                  boxShadow: AppTheme.glowShadowNavy,
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(LucideIcons.qrCode, size: 16, color: Colors.white),
                    SizedBox(width: 8),
                    Text('Start Attendance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      children: [
        // ── Previous Register Attendance: one consolidated card ──
        if (baselineSessions.isNotEmpty)
          StaggeredEntrance(
            index: 0,
            child: PressableScale(
              onTap: () => _showRegisterBaselineSheet(baselineSessions),
              pressedScale: 0.98,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF14335C), Color(0xFF0A4A5A)],
                  ),
                  borderRadius: AppTheme.cardRadius,
                  boxShadow: AppTheme.heroCardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white.withOpacity(0.2)),
                      ),
                      child: const Icon(LucideIcons.bookOpen, size: 20, color: Colors.white),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Flexible(
                                child: Text(
                                  'Previous Register Attendance',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5, color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppTheme.googleYellow.withOpacity(0.9),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  '${baselineSessions.length} classes',
                                  style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Imported from the physical register • Tap to view who attended what',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(fontSize: 11, color: Colors.white.withOpacity(0.75)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _deleteRegisterImport(baselineSessions.length),
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(LucideIcons.trash2, size: 18, color: Color(0xFFFFB4B4)),
                      ),
                    ),
                    const Icon(LucideIcons.chevronRight, size: 18, color: Colors.white),
                  ],
                ),
              ),
            ),
          ),
        if (baselineSessions.isNotEmpty) const SizedBox(height: 16),

        // ── Live QR sessions ──
        if (liveSessions.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 28),
            alignment: Alignment.center,
            child: Text(
              'No live QR sessions yet — start one to see dated session cards here.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(fontSize: 12.5, color: AppTheme.textMuted),
            ),
          )
        else
          ...List.generate(liveSessions.length, (index) {
            final sess = liveSessions[index];
            final dateStr = DateFormat('EEE, dd MMM yyyy • hh:mm a').format(sess.sessionDate);
            final pctSafe = sess.attendancePercentage >= 75.0;

            return Padding(
              padding: EdgeInsets.only(bottom: index == liveSessions.length - 1 ? 0 : 10),
              child: StaggeredEntrance(
                index: (index + 1).clamp(0, 8),
                child: PressableScale(
                  onTap: () => _showSessionDetailChart(sess),
                  pressedScale: 0.98,
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.roundedRadius,
                      border: Border.all(color: AppTheme.borderLight),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: pctSafe ? AppTheme.emeraldGreenBg : AppTheme.crimsonRoseBg,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            LucideIcons.calendarCheck2,
                            size: 18,
                            color: pctSafe ? AppTheme.emeraldGreen : AppTheme.crimsonRose,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(dateStr, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13)),
                              const SizedBox(height: 2),
                              Text(
                                'Turnout: ${sess.totalPresent} / ${sess.totalEnrolled} (${sess.attendancePercentage.toStringAsFixed(1)}%) • Tap to View Sheet',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _deleteSession(sess),
                          child: const Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(LucideIcons.trash2, size: 18, color: AppTheme.crimsonRose),
                          ),
                        ),
                        const Icon(LucideIcons.chevronRight, size: 18, color: AppTheme.textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),
      ],
    );
  }

  /// Classroom geofence editor: live OSM map with radius circle, on/off
  /// toggle, GPS capture and radius slider. Saves to cloud + local database.
  Future<void> _openGeofenceEditor() async {
    AppTheme.triggerLightHaptic();
    final subj = _activeSubject;
    bool enabled = subj.geofenceEnabled;
    double radius = subj.radiusMeters.clamp(20, 200);
    double lat = subj.latitude ?? LocationService.defaultCcsaLatitude;
    double lng = subj.longitude ?? LocationService.defaultCcsaLongitude;
    bool isLocating = false;
    int locateElapsed = 0;
    double? locateAccuracy;
    bool satelliteView = true; // default: satellite (see the actual building)
    final mapController = MapController();

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<void> captureGps() async {
            setDialogState(() {
              isLocating = true;
              locateElapsed = 0;
              locateAccuracy = null;
            });
            final pos = await LocationService.instance.getHighAccuracyPosition(
              window: const Duration(seconds: 10),
              targetAccuracy: 12.0,
              onProgress: (best, elapsed) {
                if (best != null) {
                  // Live-update the pin as better fixes arrive
                  setDialogState(() {
                    lat = best.latitude;
                    lng = best.longitude;
                    locateAccuracy = best.accuracy;
                    locateElapsed = elapsed;
                    enabled = true;
                  });
                } else {
                  setDialogState(() => locateElapsed = elapsed);
                }
              },
            );
            if (!ctx.mounted) return;
            setDialogState(() => isLocating = false);
            if (pos != null) {
              setDialogState(() {
                lat = pos.latitude;
                lng = pos.longitude;
                enabled = true;
                locateAccuracy = pos.accuracy;
              });
              mapController.move(LatLng(lat, lng), 18);
              AppTheme.triggerSuccessHaptic();
              AppTheme.showSnackBar(
                context,
                'GPS locked with ±${pos.accuracy.toStringAsFixed(0)}m accuracy.',
                isSuccess: true,
              );
            } else {
              AppTheme.showSnackBar(context, 'GPS fix unavailable — check that Location is ON and permission is granted.', isError: true);
            }
          }

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(9),
                  decoration: BoxDecoration(
                    color: (enabled ? AppTheme.emeraldGreen : AppTheme.royalNavy).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    LucideIcons.mapPin,
                    color: enabled ? AppTheme.emeraldGreen : AppTheme.royalNavy,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Classroom Geofence',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800),
                      ),
                      Text(
                        '${widget.subject.code} • ${subj.geofenceEnabled ? "Active" : "Off"}',
                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 420,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Live map preview with geofence circle
                  // Streets: CARTO Voyager (Google-like) - Satellite: Esri World Imagery
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: SizedBox(
                      height: 230,
                      child: Stack(
                        children: [
                          FlutterMap(
                            mapController: mapController,
                            options: MapOptions(
                              initialCenter: LatLng(lat, lng),
                              initialZoom: satelliteView ? 18 : 16,
                            ),
                            children: [
                              TileLayer(
                                urlTemplate: satelliteView
                                    ? 'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}'
                                    : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                                subdomains: const ['a', 'b', 'c', 'd'],
                                maxNativeZoom: satelliteView ? 19 : 20,
                                userAgentPackageName: 'com.ccsa.du',
                              ),
                              CircleLayer(
                                circles: [
                                  CircleMarker(
                                    point: LatLng(lat, lng),
                                    radius: radius,
                                    useRadiusInMeter: true,
                                    color: AppTheme.googleBlue.withOpacity(satelliteView ? 0.28 : 0.18),
                                    borderColor: satelliteView ? Colors.white : AppTheme.googleBlue,
                                    borderStrokeWidth: 2,
                                  ),
                                ],
                              ),
                              if (locateAccuracy != null)
                                CircleLayer(
                                  circles: [
                                    CircleMarker(
                                      point: LatLng(lat, lng),
                                      radius: locateAccuracy!.clamp(1, 300),
                                      useRadiusInMeter: true,
                                      color: AppTheme.googleYellow.withOpacity(0.14),
                                      borderColor: AppTheme.googleYellow,
                                      borderStrokeWidth: 1.5,
                                    ),
                                  ],
                                ),
                              MarkerLayer(
                                markers: [
                                  Marker(
                                    point: LatLng(lat, lng),
                                    width: 40,
                                    height: 40,
                                    child: const Icon(
                                      LucideIcons.mapPin,
                                      size: 32,
                                      color: AppTheme.crimsonRose,
                                    ),
                                  ),
                                ],
                              ),
                              RichAttributionWidget(
                                attributions: [
                                  const TextSourceAttribution('© OpenStreetMap contributors'),
                                  if (satelliteView)
                                    const TextSourceAttribution('Imagery © Esri'),
                                  if (!satelliteView)
                                    const TextSourceAttribution('© CARTO'),
                                ],
                              ),
                            ],
                          ),
                          // Map/Satellite layer toggle (Google Maps style)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: Material(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(10),
                              elevation: 2,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(10),
                                onTap: () {
                                  AppTheme.triggerSelectionHaptic();
                                  setDialogState(() => satelliteView = !satelliteView);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.all(7),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        satelliteView ? LucideIcons.map : LucideIcons.satellite,
                                        size: 15,
                                        color: AppTheme.royalNavy,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        satelliteView ? 'Street' : 'Satellite',
                                        style: GoogleFonts.inter(
                                          fontSize: 10.5,
                                          fontWeight: FontWeight.w800,
                                          color: AppTheme.royalNavy,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLocating
                        ? 'Locating… ${locateElapsed}s${locateAccuracy != null ? " • best ±${locateAccuracy!.toStringAsFixed(0)}m" : ""}'
                        : 'Lat ${lat.toStringAsFixed(5)} • Lng ${lng.toStringAsFixed(5)}${locateAccuracy != null ? " (±${locateAccuracy!.toStringAsFixed(0)}m)" : ""}',
                    style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textMuted),
                  ),
                  const SizedBox(height: 10),

                  // On/off toggle
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enforce GPS Geofence',
                              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.royalNavy),
                            ),
                            Text(
                              enabled ? 'Students must be inside the circle to scan' : 'Anyone can scan from anywhere',
                              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: enabled,
                        activeColor: AppTheme.emeraldGreen,
                        onChanged: (v) {
                          AppTheme.triggerSelectionHaptic();
                          setDialogState(() => enabled = v);
                        },
                      ),
                    ],
                  ),

                  if (enabled) ...[
                    const Divider(height: 20, color: AppTheme.borderSubtle),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Allowed Radius',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                        Text(
                          '${radius.toInt()} meters',
                          style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.googleBlue),
                        ),
                      ],
                    ),
                    Slider(
                      value: radius,
                      min: 20,
                      max: 200,
                      divisions: 18,
                      activeColor: AppTheme.googleBlue,
                      label: '${radius.toInt()}m',
                      onChanged: (v) => setDialogState(() => radius = v),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.googleBlue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: isLocating
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(LucideIcons.locateFixed, size: 15),
                        label: Text(
                          isLocating ? 'Locking GPS… hold still' : 'My GPS (high accuracy)',
                          style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                        ),
                        onPressed: isLocating ? null : captureGps,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalNavy,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: () async {
                  final updatedSub = Subject(
                    id: subj.id,
                    name: subj.name,
                    code: subj.code,
                    professorName: subj.professorName,
                    course: subj.course,
                    semester: subj.semester,
                    batchType: subj.batchType,
                    teacherEmail: subj.teacherEmail,
                    enrolledStudentIds: subj.enrolledStudentIds,
                    geofenceEnabled: enabled,
                    latitude: enabled ? lat : null,
                    longitude: enabled ? lng : null,
                    radiusMeters: radius,
                    createdAt: subj.createdAt,
                  );

                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);
                  setState(() => _currentSubject = updatedSub);

                  // Cloud sync + local cache
                  await ApiService.instance.syncSubject(updatedSub);
                  try {
                    await DatabaseHelper.instance.insertSubject(updatedSub);
                  } catch (_) {}

                  nav.pop();
                  AppTheme.triggerSuccessHaptic();
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(enabled
                          ? 'Geofence ON — students must be within ${radius.toInt()}m of the classroom to scan.'
                          : 'Geofence OFF — attendance can be scanned from anywhere.'),
                      backgroundColor: enabled ? AppTheme.emeraldGreen : AppTheme.amberWarning,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Permanently delete a single session (cloud + local) after explicit
  /// confirmation. Uses delete_subject_sessions.php with the exact session id.
  Future<void> _deleteSession(AttendanceSession sess) async {
    AppTheme.triggerLightHaptic();
    final dateStr = DateFormat('EEE, dd MMM yyyy • hh:mm a').format(sess.sessionDate);

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
              child: const Icon(LucideIcons.trash2, color: AppTheme.crimsonRose, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Session Permanently?',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'This will permanently delete the session from "$dateStr" and ALL of its attendance records from the university cloud database and this device.\n\nStudents marked present in this session will lose this class from their attendance history.\n\nThis action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 12.5, height: 1.5, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.crimsonRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    bool cloudDeleted = false;
    try {
      cloudDeleted = await ApiService.instance.deleteSubjectSessions(widget.subject.id, sess.id);
    } catch (e) {
      debugPrint('Cloud session delete failed: $e');
    }

    // Local cache cleanup
    try {
      final db = await DatabaseHelper.instance.database;
      await db.delete('attendance_records', where: 'session_id = ?', whereArgs: [sess.id]);
      await db.delete('attendance_sessions', where: 'id = ?', whereArgs: [sess.id]);
    } catch (_) {}

    if (!mounted) return;
    if (cloudDeleted) {
      AppTheme.triggerSuccessHaptic();
      AppTheme.showSnackBar(context, 'Session permanently deleted from the database.', isSuccess: true);
    } else {
      AppTheme.showSnackBar(
        context,
        'Removed on this device, but the cloud delete failed — make sure delete_subject_sessions.php is uploaded to the server.',
        isError: true,
      );
    }
    await _loadData();
  }

  /// Permanently delete the whole physical-register baseline import.
  Future<void> _deleteRegisterImport(int baselineCount) async {
    AppTheme.triggerLightHaptic();

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
              child: const Icon(LucideIcons.trash2, color: AppTheme.crimsonRose, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Register Attendance?',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'All $baselineCount imported register classes and their attendance records will be permanently removed from the university cloud database and this device.\n\nLive QR sessions are NOT affected.\n\nThis action cannot be undone.',
          style: GoogleFonts.inter(fontSize: 12.5, height: 1.5, color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.crimsonRose,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Forever', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    final baselinePrefix = 'baseline_${widget.subject.id}_';

    bool cloudDeleted = false;
    try {
      cloudDeleted = await ApiService.instance.deleteSubjectSessions(widget.subject.id, baselinePrefix);
    } catch (e) {
      debugPrint('Cloud baseline delete failed: $e');
    }

    try {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery(
        "SELECT id FROM attendance_sessions WHERE subject_id = ? AND id LIKE ?",
        [widget.subject.id, '$baselinePrefix%'],
      );
      for (final row in rows) {
        final sid = row['id'] as String;
        await db.delete('attendance_records', where: 'session_id = ?', whereArgs: [sid]);
        await db.delete('attendance_sessions', where: 'id = ?', whereArgs: [sid]);
      }
    } catch (_) {}

    if (!mounted) return;
    if (cloudDeleted) {
      AppTheme.triggerSuccessHaptic();
      AppTheme.showSnackBar(context, 'Register attendance permanently deleted from the database.', isSuccess: true);
    } else {
      AppTheme.showSnackBar(
        context,
        'Removed on this device, but the cloud delete failed — make sure delete_subject_sessions.php is uploaded to the server.',
        isError: true,
      );
    }
    await _loadData();
  }

  /// Sheet listing per-student attendance imported from the physical register.
  void _showRegisterBaselineSheet(List<AttendanceSession> baselineSessions) {
    AppTheme.triggerLightHaptic();

    // Compute per-student attended counts across baseline sessions
    final Map<String, int> attendedByStudent = {};
    for (final sess in baselineSessions) {
      for (final rec in sess.records) {
        if (!rec.isPresent) continue;
        for (final s in _students) {
          final matches = rec.studentId == s.id ||
              (rec.studentRollNo.isNotEmpty && rec.studentRollNo == s.classRollNo) ||
              (rec.studentName.isNotEmpty && rec.studentName.toLowerCase() == s.name.toLowerCase());
          if (matches) {
            attendedByStudent[s.id] = (attendedByStudent[s.id] ?? 0) + 1;
            break;
          }
        }
      }
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgLight,
      builder: (bCtx) {
        return Container(
          constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(color: AppTheme.borderLight, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(height: 14),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: AppTheme.royalNavy.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(LucideIcons.bookOpen, color: AppTheme.royalNavy, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Previous Register Attendance',
                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 16, color: AppTheme.royalNavy),
                          ),
                          Text(
                            '${baselineSessions.length} classes imported from the physical register',
                            style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(LucideIcons.x, size: 20),
                      onPressed: () => Navigator.pop(bCtx),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              const Divider(height: 1, color: AppTheme.borderSubtle),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: _students.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
                  itemBuilder: (context, index) {
                    final s = _students[index];
                    final attended = attendedByStudent[s.id] ?? 0;
                    final pct = baselineSessions.isNotEmpty ? (attended / baselineSessions.length) * 100 : 0.0;
                    final rollDisplay = s.classRollNo.isNotEmpty ? s.classRollNo : '${index + 1}';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: AppTheme.royalNavy.withOpacity(0.08),
                        child: Text(
                          rollDisplay,
                          style: GoogleFonts.sourceCodePro(fontWeight: FontWeight.w800, fontSize: 12, color: AppTheme.royalNavy),
                        ),
                      ),
                      title: Text(
                        s.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      subtitle: Text(
                        '$attended of ${baselineSessions.length} classes attended',
                        style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: pct >= 80 ? AppTheme.emeraldGreenBg : AppTheme.crimsonRoseBg,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: pct >= 80 ? AppTheme.emeraldGreenBorder : AppTheme.crimsonRoseBorder),
                        ),
                        child: Text(
                          '${pct.toStringAsFixed(0)}%',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: pct >= 80 ? const Color(0xFF047857) : AppTheme.crimsonRose,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
        const SizedBox(height: 3),
        Text(value, style: GoogleFonts.plusJakartaSans(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      ],
    );
  }
}
