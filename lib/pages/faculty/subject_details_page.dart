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
import '../../theme/app_theme.dart';
import '../../widgets/marquee_text.dart';
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
      // 1. Try local SQLite first (mobile/desktop)
      try {
        stds = await DatabaseHelper.instance.getStudentsForSubject(widget.subject.id);
        sess = await DatabaseHelper.instance.getSessionsForSubject(widget.subject.id);
      } catch (_) {}

      // 2. Fetch from Cloud MySQL (guarantees web works 100%)
      if (sess.isEmpty) {
        final cloudSess = await ApiService.instance.getFacultySessions(subjectId: widget.subject.id);
        if (cloudSess.isNotEmpty) sess = cloudSess;
      }

      if (stds.isEmpty) {
        final cloudStds = await ApiService.instance.getRegisteredStudents(
          course: widget.subject.course,
          semester: widget.subject.semester,
        );
        if (cloudStds.isNotEmpty) {
          final enrolledSet = widget.subject.enrolledStudentIds.toSet();
          if (enrolledSet.isNotEmpty) {
            stds = cloudStds.where((s) => enrolledSet.contains(s.id)).toList();
          }
          if (stds.isEmpty) stds = cloudStds;
        }
      }

      // Calculate subject attendance statistics
      for (var s in stds) {
        int totalHeld = sess.length;
        int attended = 0;
        for (var session in sess) {
          final isPresent = session.records.any((r) =>
              (r.studentId == s.id || r.studentRollNo == s.classRollNo) && r.isPresent);
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
    } catch (e) {
      debugPrint('Subject details load error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _students = stds;
          _sessions = sess;
          _studentStats = stats;
          _isLoading = false;
        });
      }
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('All registered ${widget.subject.course} ${widget.subject.semesterDisplay} students are already enrolled!'),
          backgroundColor: AppTheme.electricTeal,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final Set<String> newlySelectedIds = {};

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.royalNavy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.userPlus, color: AppTheme.royalNavy, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Add Student to Subject',
                    style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
  Future<void> _openPhysicalRegisterBaselineDialog() async {
    AppTheme.triggerLightHaptic();
    if (_students.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No students enrolled in this subject yet.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
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

          return AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.royalNavy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.bookOpen, color: AppTheme.royalNavy, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import Past Register Attendance',
                        style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Baseline offline attendance from physical register',
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
                        borderRadius: BorderRadius.circular(12),
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
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
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
                          'Student Attendance Counts:',
                          style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                        ),
                        TextButton.icon(
                          icon: const Icon(LucideIcons.checkCheck, size: 14),
                          label: const Text('Set All to Max', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                          onPressed: () {
                            final max = totalClassesCtrl.text;
                            setDialogState(() {
                              for (final ctrl in studentCounts.values) {
                                ctrl.text = max;
                              }
                            });
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Container(
                      constraints: const BoxConstraints(maxHeight: 280),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppTheme.borderSubtle),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: _students.length,
                        separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
                        itemBuilder: (context, index) {
                          final s = _students[index];
                          final ctrl = studentCounts[s.id]!;
                          final rollDisplay = s.classRollNo.isNotEmpty ? 'Roll ${s.classRollNo}' : 'Roll ${index + 1}';

                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: AppTheme.royalNavy.withOpacity(0.08),
                                  child: Text(
                                    s.classRollNo.isNotEmpty ? s.classRollNo : '${index + 1}',
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5)),
                                      Text(rollDisplay, style: GoogleFonts.inter(fontSize: 10.5, color: AppTheme.textSecondary)),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(LucideIcons.minusCircle, size: 18, color: AppTheme.crimsonRose),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    final current = int.tryParse(ctrl.text) ?? 0;
                                    if (current > 0) {
                                      ctrl.text = '${current - 1}';
                                      setDialogState(() {});
                                    }
                                  },
                                ),
                                const SizedBox(width: 6),
                                SizedBox(
                                  width: 44,
                                  child: TextField(
                                    controller: ctrl,
                                    keyboardType: TextInputType.number,
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                                    decoration: InputDecoration(
                                      isDense: true,
                                      contentPadding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(6)),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                IconButton(
                                  icon: const Icon(LucideIcons.plusCircle, size: 18, color: AppTheme.emeraldGreen),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: () {
                                    final current = int.tryParse(ctrl.text) ?? 0;
                                    if (current < totalHeld) {
                                      ctrl.text = '${current + 1}';
                                      setDialogState(() {});
                                    }
                                  },
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);
                  final int nClasses = int.tryParse(totalClassesCtrl.text) ?? 0;
                  if (nClasses <= 0) {
                    messenger.showSnackBar(const SnackBar(content: Text('Please enter a valid number of classes (>= 1).')));
                    return;
                  }

                  nav.pop();
                  setState(() => _isLoading = true);

                  final user = AuthService.instance.currentUser;
                  final now = DateTime.now();

                  // Create N past register sessions
                  for (int k = 1; k <= nClasses; k++) {
                    final sessionId = const Uuid().v4();
                    final sessionDate = now.subtract(Duration(days: (nClasses - k + 1)));

                    int presentCount = 0;
                    final List<AttendanceRecord> records = [];

                    for (final s in _students) {
                      final attendedCount = int.tryParse(studentCounts[s.id]?.text ?? '0') ?? 0;
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
                      content: Text('Successfully imported $nClasses physical register lectures!'),
                      backgroundColor: AppTheme.emeraldGreen,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
                child: const Text('Save Past Attendance', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          );
        },
      ),
    );
  }

  // View Full Session Attendance Chart / Breakdown (Request 3)
  void _showSessionDetailChart(AttendanceSession session) async {
    AppTheme.triggerLightHaptic();
    final db = await DatabaseHelper.instance.database;
    final records = await db.query(
      'attendance_records',
      where: 'session_id = ?',
      whereArgs: [session.id],
    );

    final Set<String> presentStudentIds = {};
    for (final r in records) {
      if ((r['status'] as String?)?.toLowerCase() == 'present') {
        presentStudentIds.add(r['student_id'] as String);
      }
    }

    if (!mounted) return;

    final dateFormatted = DateFormat('EEE, dd MMM yyyy • hh:mm a').format(session.sessionDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (bCtx) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
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

              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                          Text(dateFormatted, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
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
              const SizedBox(height: 12),

              // Session Summary Pill
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppTheme.bgLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.borderLight),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Row(
                        children: [
                          const Icon(LucideIcons.checkCircle2, size: 16, color: Color(0xFF047857)),
                          const SizedBox(width: 6),
                          Text('Present: ${presentStudentIds.length}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF047857))),
                        ],
                      ),
                      Container(width: 1, height: 24, color: AppTheme.borderLight),
                      Row(
                        children: [
                          const Icon(LucideIcons.xCircle, size: 16, color: AppTheme.crimsonRose),
                          const SizedBox(width: 6),
                          Text('Absent: ${_students.length - presentStudentIds.length}', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.crimsonRose)),
                        ],
                      ),
                      Container(width: 1, height: 24, color: AppTheme.borderLight),
                      Text(
                        '${session.attendancePercentage.toStringAsFixed(1)}%',
                        style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Student List with Present / Absent Status (Prominent Roll Numbers - Item 1)
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                  itemCount: _students.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
                  itemBuilder: (context, index) {
                    final std = _students[index];
                    final isPresent = presentStudentIds.contains(std.id);
                    final rollNo = std.classRollNo.isNotEmpty ? std.classRollNo : '${index + 1}';

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
                        std.name,
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
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    int totalPresentAcrossSessions = 0;
    for (var s in _sessions) {
      totalPresentAcrossSessions += s.totalPresent;
    }
    final avgAttendance = _sessions.isNotEmpty && _students.isNotEmpty
        ? (totalPresentAcrossSessions / (_sessions.length * _students.length)) * 100
        : 0.0;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            MarqueeText(
              text: widget.subject.name,
              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            Text(
              '${widget.subject.code} • ${widget.subject.course} ${widget.subject.semesterDisplay}',
              style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
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
          labelStyle: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: [
            Tab(text: 'Enrolled Roster (${_students.length})'),
            Tab(text: 'Past Sessions (${_sessions.length})'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.royalNavy))
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
          child: ElevatedButton.icon(
            onPressed: () async {
              final taken = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => DynamicQrSessionPage(subject: widget.subject)),
              );
              if (taken == true) _loadData();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.royalNavy,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(LucideIcons.qrCode, size: 18),
            label: Text(
              'Start Attendance',
              style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 14),
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
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppTheme.borderLight)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _openAddStudentDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.royalNavy,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(LucideIcons.userPlus, size: 15),
                label: const Text('Add Student', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Text(
            'Enrolled Students (${filteredStudents.length})',
            style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
          ),
          const SizedBox(height: 10),

          if (filteredStudents.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.roundedRadius,
                border: Border.all(color: AppTheme.borderLight),
              ),
              child: Column(
                children: [
                  const Icon(LucideIcons.userX, size: 36, color: AppTheme.textSecondary),
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

                return InkWell(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => StudentAttendanceDialog(
                        subject: widget.subject,
                        stats: st,
                      ),
                    );
                  },
                  borderRadius: AppTheme.roundedRadius,
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
                              style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 14, color: AppTheme.royalNavy),
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
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildSessionsTab() {
    if (_sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(LucideIcons.calendarX, size: 40, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text('No sessions recorded yet.', style: GoogleFonts.inter(fontSize: 14, color: AppTheme.textSecondary)),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () async {
                final taken = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => DynamicQrSessionPage(subject: widget.subject)),
                );
                if (taken == true) _loadData();
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.royalNavy),
              icon: const Icon(LucideIcons.qrCode, size: 16),
              label: const Text('Start Attendance'),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      itemCount: _sessions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final sess = _sessions[index];
        final dateStr = DateFormat('EEE, dd MMM yyyy • hh:mm a').format(sess.sessionDate);

        return InkWell(
          onTap: () => _showSessionDetailChart(sess),
          borderRadius: AppTheme.roundedRadius,
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
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.royalNavy.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(LucideIcons.calendarCheck2, size: 18, color: AppTheme.royalNavy),
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
                        style: const TextStyle(fontSize: 11.5, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
                const Icon(LucideIcons.chevronRight, size: 18, color: AppTheme.textSecondary),
              ],
            ),
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
