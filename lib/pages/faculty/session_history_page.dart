import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../db/database_helper.dart';
import '../../models/attendance_session.dart';
import '../../models/student.dart';
import '../../models/subject.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_cards.dart';
import '../../widgets/doodle_art.dart';
import '../../widgets/micro_interactions.dart';
import '../../widgets/responsive_layout.dart';

class SessionHistoryPage extends StatefulWidget {
  final Subject? subject;

  const SessionHistoryPage({super.key, this.subject});

  @override
  State<SessionHistoryPage> createState() => _SessionHistoryPageState();
}

class _SessionHistoryPageState extends State<SessionHistoryPage> {
  List<AttendanceSession> _sessions = [];
  bool _isLoading = true;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadSessions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    final user = AuthService.instance.currentUser;
    final email = user?.email ?? 'faculty@ccsa.du.ac.in';
    List<AttendanceSession> sess = [];

    try {
      // 1. Fetch live authoritative sessions from Hostinger MySQL
      sess = await ApiService.instance.getFacultySessions(
        teacherEmail: email,
        subjectId: widget.subject?.id,
      );

      // Reconcile local SQLite cache: remove deleted sessions
      try {
        final db = await DatabaseHelper.instance.database;
        final localSessions = widget.subject != null 
            ? await DatabaseHelper.instance.getSessionsForSubject(widget.subject!.id)
            : await DatabaseHelper.instance.getAllSessionsForTeacher(email);
        final cloudSessionIds = sess.map((s) => s.id).toSet();
        for (var localS in localSessions) {
          if (!cloudSessionIds.contains(localS.id)) {
            await db.delete('attendance_records', where: 'session_id = ?', whereArgs: [localS.id]);
            await db.delete('attendance_sessions', where: 'id = ?', whereArgs: [localS.id]);
          }
        }
      } catch (_) {}
    } catch (e) {
      debugPrint('Error loading sessions from cloud (using offline fallback): $e');
      try {
        if (widget.subject != null) {
          sess = await DatabaseHelper.instance.getSessionsForSubject(widget.subject!.id);
        } else {
          sess = await DatabaseHelper.instance.getAllSessionsForTeacher(email);
        }
      } catch (_) {}
    } finally {
      if (mounted) {
        setState(() {
          _sessions = sess;
          _isLoading = false;
        });
      }
    }
  }

  void _showSessionDetailSheet(AttendanceSession session) {
    AppTheme.triggerLightHaptic();
    final dateFormatted = DateFormat('EEE, dd MMM yyyy • hh:mm a').format(session.sessionDate);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgLight,
      builder: (bCtx) {
        final theme = Theme.of(context);

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
          List<Student> enrolledStudents = [];
          try {
            final db = await DatabaseHelper.instance.database;
            records = await db.query(
              'attendance_records',
              where: 'session_id = ?',
              whereArgs: [session.id],
            );
            enrolledStudents = await DatabaseHelper.instance.getStudentsForSubject(session.subjectId);
          } catch (_) {}

          final List<Map<String, dynamic>> unified = [];
          int presentCount = 0;

          if (enrolledStudents.isNotEmpty) {
            for (final std in enrolledStudents) {
              final isPresent = records.any((r) {
                final sid = r['student_id'] as String? ?? '';
                final sroll = r['student_roll_no'] as String? ?? '';
                final sname = (r['student_name'] as String? ?? '').toLowerCase();
                return (sid.isNotEmpty && sid == std.id) ||
                    (sroll.isNotEmpty && sroll == std.classRollNo) ||
                    (sname.isNotEmpty && sname == std.name.toLowerCase()) ||
                    (std.email != null && std.email!.isNotEmpty && sid.toLowerCase() == std.email!.toLowerCase());
              });

              if (isPresent) presentCount++;

              unified.add({
                'id': std.id,
                'student_name': std.name,
                'student_roll_no': std.classRollNo,
                'du_exam_roll_no': std.duExamRollNo,
                'status': isPresent ? 'present' : 'absent',
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

        return Container(
          height: MediaQuery.of(context).size.height * 0.85,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: FutureBuilder<Map<String, dynamic>>(
            future: fetchDetails(),
            builder: (context, snapshot) {
              final isLoading = snapshot.connectionState == ConnectionState.waiting;
              final data = snapshot.data;
              final records = (data?['records'] as List<Map<String, dynamic>>?) ?? [];
              final totalPresent = (data?['total_present'] as int?) ?? session.totalPresent;
              final totalEnrolled = (data?['total_enrolled'] as int?) ?? session.totalEnrolled;
              final percentage = (data?['percentage'] as double?) ?? session.attendancePercentage;
              final totalAbsent = (totalEnrolled - totalPresent).clamp(0, totalEnrolled);

              return Column(
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

                  // Sheet Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Session Attendance Sheet',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 17, color: AppTheme.royalNavy),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${session.subjectCode}: ${session.subjectName} • $dateFormatted',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                  const SizedBox(height: 12),

                  // Session Summary Tonal Pill
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.bgLight,
                        borderRadius: AppTheme.cardRadius,
                        border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.7)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Row(
                            children: [
                              const Icon(LucideIcons.checkCircle2, size: 16, color: Color(0xFF047857)),
                              const SizedBox(width: 6),
                              Text('Present: $totalPresent', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: const Color(0xFF047857))),
                            ],
                          ),
                          Container(width: 1, height: 20, color: AppTheme.borderLight),
                          Row(
                            children: [
                              const Icon(LucideIcons.xCircle, size: 16, color: AppTheme.crimsonRose),
                              const SizedBox(width: 6),
                              Text('Absent: $totalAbsent', style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w700, color: AppTheme.crimsonRose)),
                            ],
                          ),
                          Container(width: 1, height: 20, color: AppTheme.borderLight),
                          Text(
                            '${percentage.toStringAsFixed(1)}%',
                            style: GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Student Attendance List with Status Tags
                  Expanded(
                    child: isLoading
                        ? const Center(child: CircularProgressIndicator(color: AppTheme.royalNavy))
                        : records.isEmpty
                            ? Center(
                                child: Text(
                                  'No attendance records found for this session.',
                                  style: GoogleFonts.inter(color: AppTheme.textSecondary),
                                ),
                              )
                            : ListView.separated(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                                itemCount: records.length,
                                separatorBuilder: (_, __) => Divider(height: 1, color: theme.colorScheme.outlineVariant.withOpacity(0.5)),
                                itemBuilder: (context, index) {
                                  final rec = records[index];
                                  final isPresent = (rec['status'] as String?)?.toLowerCase() == 'present';
                                  final rollNo = (rec['student_roll_no'] as String? ?? '').isNotEmpty
                                      ? rec['student_roll_no'] as String
                                      : '${index + 1}';
                                  final name = (rec['student_name'] as String? ?? '').isNotEmpty
                                      ? rec['student_name'] as String
                                      : 'Student';
                                  final duExamRoll = rec['du_exam_roll_no'] as String? ?? '';

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                    leading: CircleAvatar(
                                      radius: 18,
                                      backgroundColor: isPresent ? AppTheme.emeraldGreenBg : AppTheme.crimsonRoseBg,
                                      child: Text(
                                        rollNo,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 11,
                                          color: isPresent ? const Color(0xFF047857) : AppTheme.crimsonRose,
                                        ),
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 13.5),
                                    ),
                                    subtitle: Text(
                                      duExamRoll.isNotEmpty ? 'Roll: $rollNo • DU: $duExamRoll' : 'Roll: $rollNo',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary),
                                    ),
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
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = Responsive.isWide(context);
    final isDesktop = Responsive.isDesktop(context);
    final DateFormat df = DateFormat('EEE, dd MMM yyyy • hh:mm a');

    final filtered = _sessions.where((s) {
      if (_searchQuery.isEmpty) return true;
      final q = _searchQuery.toLowerCase();
      return s.subjectName.toLowerCase().contains(q) || s.subjectCode.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(
          widget.subject != null ? '${widget.subject!.code} Session History' : 'Session History',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: BrandLoader(message: 'Loading sessions…', size: 44))
          : Scrollbar(
              controller: _scrollController,
              thumbVisibility: isDesktop,
              child: AdaptiveContainer(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                child: Column(
                  children: [
                    if (_sessions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: TextField(
                          controller: _searchController,
                          onChanged: (v) => setState(() => _searchQuery = v.trim()),
                          decoration: InputDecoration(
                            hintText: 'Search sessions by subject or code...',
                            prefixIcon: const Icon(LucideIcons.search, size: 18, color: AppTheme.textSecondary),
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(LucideIcons.x, size: 16),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          ),
                        ),
                      ),
                    Expanded(
                      child: filtered.isEmpty
                          ? Center(
                              child: EmptyStateWidget(
                                scene: _searchQuery.isNotEmpty ? DoodleScene.magnifier : DoodleScene.clipboardCheck,
                                icon: LucideIcons.calendarX,
                                title: _searchQuery.isNotEmpty ? 'No Matching Sessions' : 'No Sessions Conducted Yet',
                                subtitle: _searchQuery.isNotEmpty
                                    ? 'No attendance records match "$_searchQuery".'
                                    : 'When attendance sessions are conducted, they will appear in this timeline.',
                              ),
                            )
                          : isWide
                              ? GridView.builder(
                                  controller: _scrollController,
                                  physics: const BouncingScrollPhysics(),
                                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: 2,
                                    crossAxisSpacing: 16,
                                    mainAxisSpacing: 14,
                                    mainAxisExtent: 96,
                                  ),
                                  itemCount: filtered.length,
                                  itemBuilder: (context, index) {
                                    final s = filtered[index];
                                    return StaggeredEntrance(
                                      index: index.clamp(0, 8),
                                      child: _buildSessionCard(s, df, theme),
                                    );
                                  },
                                )
                              : ListView.separated(
                                  controller: _scrollController,
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: filtered.length,
                                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                                  itemBuilder: (context, index) {
                                    final s = filtered[index];
                                    return StaggeredEntrance(
                                      index: index.clamp(0, 8),
                                      child: _buildSessionCard(s, df, theme),
                                    );
                                  },
                                ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildSessionCard(AttendanceSession s, DateFormat df, ThemeData theme) {
    final isHighTurnout = s.attendancePercentage >= 75.0;

    return PressableScale(
      onTap: () => _showSessionDetailSheet(s),
      pressedScale: 0.975,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.cardRadius,
          border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.7), width: 1.0),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Leading GPay Transaction Style Avatar Circle
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: s.isLab ? AppTheme.amberWarningBg : AppTheme.electricTealBg,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Icon(
                  s.isLab ? LucideIcons.flaskConical : LucideIcons.bookOpen,
                  size: 20,
                  color: s.isLab ? const Color(0xFFB45309) : AppTheme.electricTeal,
                ),
              ),
            ),
              const SizedBox(width: 14),

              // Subject & Date
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${s.subjectCode}: ${s.subjectName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      df.format(s.sessionDate),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Trailing Ratio & Badge
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${s.totalPresent} / ${s.totalEnrolled}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: isHighTurnout ? AppTheme.emeraldGreen : AppTheme.crimsonRose,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: isHighTurnout ? AppTheme.emeraldGreenBg : AppTheme.crimsonRoseBg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${s.attendancePercentage.toStringAsFixed(0)}%',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: isHighTurnout ? AppTheme.emeraldGreen : AppTheme.crimsonRose,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 6),
              const Icon(LucideIcons.chevronRight, size: 16, color: AppTheme.textSecondary),
            ],
          ),
        ),
    );
  }
}
