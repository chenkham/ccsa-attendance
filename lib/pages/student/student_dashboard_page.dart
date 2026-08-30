import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../db/database_helper.dart';
import '../../models/student.dart';
import '../../models/subject.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/attendance_chart.dart';
import '../../widgets/attendance_gauge.dart';
import '../../widgets/custom_cards.dart';
import '../../widgets/marquee_text.dart';
import '../../widgets/responsive_layout.dart';
import '../../widgets/student_attendance_dialog.dart';
import '../common/settings_page.dart';
import '../profile/profile_page.dart';
import 'qr_scanner_page.dart';
import 'student_history_page.dart';

class StudentDashboardPage extends StatefulWidget {
  const StudentDashboardPage({super.key});

  @override
  State<StudentDashboardPage> createState() => _StudentDashboardPageState();
}

class _StudentDashboardPageState extends State<StudentDashboardPage> {
  Student? _student;
  List<Subject> _enrolledSubjects = [];
  Map<String, Map<String, dynamic>> _subjectStats = {};
  bool _isLoading = true;
  int _navIndex = 0;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadStudentData();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadStudentData() async {
    setState(() => _isLoading = true);
    final user = AuthService.instance.currentUser;
    var std = AuthService.instance.currentStudent;

    if (std == null && user != null) {
      try {
        std = await DatabaseHelper.instance.getStudentById(user.id);
        if (std == null && user.studentRollNo != null) {
          std = await DatabaseHelper.instance.getStudentByRollNo(user.studentRollNo!);
        }
      } catch (_) {}

      // Fallback std construction from user model if local db is empty/web
      std ??= Student(
        id: user.id,
        name: user.name,
        classRollNo: user.studentRollNo ?? '',
        duExamRollNo: user.duExamRollNo ?? '',
        course: user.course ?? 'BCA',
        semester: user.semester ?? 1,
        email: user.email,
        boundDeviceId: user.deviceId,
        createdAt: user.createdAt,
      );
    }

    List<Subject> subs = [];
    Map<String, Map<String, dynamic>> stats = {};

    try {
      if (std != null && user != null) {
        // 1. Fetch enrolled subjects from Hostinger MySQL Cloud
        subs = await ApiService.instance.getStudentSubjectsFromCloud(
          email: user.email,
          studentId: std.id,
        );

        if (subs.isNotEmpty) {
          // Reconcile local SQLite (safe on mobile/desktop, skipped on web)
          try {
            final localSubs = await DatabaseHelper.instance.getSubjectsForStudent(std.id);
            final cloudSubIds = subs.map((s) => s.id).toSet();
            for (var local in localSubs) {
              if (!cloudSubIds.contains(local.id)) {
                await DatabaseHelper.instance.deleteSubject(local.id);
              }
            }
            for (var s in subs) {
              await DatabaseHelper.instance.insertSubject(s);
            }
          } catch (e) {
            debugPrint('Local SQLite sync skipped on student dashboard: $e');
          }
        } else {
          try {
            subs = await DatabaseHelper.instance.getSubjectsForStudent(std.id);
          } catch (_) {}
        }

        // 2. Fetch live cloud attendance statistics directly from Hostinger MySQL
        final cloudData = await ApiService.instance.getStudentAttendanceFromCloud(
          email: user.email,
          studentId: std.id,
        );

        if (cloudData != null && cloudData['stats'] is Map) {
          final cloudStats = cloudData['stats'] as Map<String, dynamic>;
          for (var s in subs) {
            if (cloudStats.containsKey(s.id) || cloudStats.containsKey(s.code)) {
              final st = (cloudStats[s.id] ?? cloudStats[s.code]) as Map<String, dynamic>;
              final sessions = (st['sessions'] as List?) ?? [];
              final attended = sessions.where((x) => x['status'] == 'present').length;
              stats[s.id] = {
                'total': st['total_held'] ?? 0,
                'attended': st['total_attended'] ?? 0,
                'missed': st['missed'] ?? 0,
                'totalSessions': sessions.length,
                'attendedSessions': attended,
                'totalLabHours': 0,
                'attendedLabHours': 0,
                'percentage': (st['percentage'] as num?)?.toDouble() ?? 100.0,
                'history': sessions,
              };
            } else {
              stats[s.id] = {
                'total': 0,
                'attended': 0,
                'missed': 0,
                'totalSessions': 0,
                'attendedSessions': 0,
                'totalLabHours': 0,
                'attendedLabHours': 0,
                'percentage': 100.0,
                'history': [],
              };
            }
          }
        } else {
          try {
            for (var s in subs) {
              stats[s.id] = await DatabaseHelper.instance.getStudentSubjectAttendanceStats(std.id, s.id);
            }
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('Student data load error: $e');
    } finally {
      if (mounted) {
        setState(() {
          _student = std;
          _enrolledSubjects = subs;
          _subjectStats = stats;
          _isLoading = false;
        });
      }
    }
  }

  void _showSubjectDetailModal(Subject subject) {
    AppTheme.triggerLightHaptic();
    final stats = _subjectStats[subject.id];
    if (stats == null) return;

    showDialog(
      context: context,
      builder: (ctx) => StudentAttendanceDialog(
        subject: subject,
        stats: stats,
      ),
    );
  }



  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isDesktop = Responsive.isDesktop(context);

    final bool isProfileIncomplete = user?.profileCompleted != true ||
        user?.studentRollNo == null ||
        user!.studentRollNo!.isEmpty;

    int totalClassesHeld = 0;
    int totalClassesAttended = 0;

    _subjectStats.forEach((_, st) {
      totalClassesHeld += (st['total'] as int? ?? 0);
      totalClassesAttended += (st['attended'] as int? ?? 0);
    });

    final double overallPercentage = totalClassesHeld > 0
        ? (totalClassesAttended / totalClassesHeld) * 100
        : 100.0;

    final chartItems = _enrolledSubjects.map((s) {
      final st = _subjectStats[s.id];
      final pct = (st?['percentage'] as num?)?.toDouble() ?? 100.0;
      final att = (st?['attended'] as int?) ?? 0;
      final tot = (st?['total'] as int?) ?? 0;
      return AttendanceBarItem(
        label: '${s.code} - ${s.name}',
        percentage: pct,
        attended: att,
        total: tot,
      );
    }).toList();

    final navItems = [
      AdaptiveNavItem(
        icon: LucideIcons.layoutDashboard,
        selectedIcon: LucideIcons.layoutDashboard,
        label: 'Home',
        onTap: () => setState(() => _navIndex = 0),
      ),
      AdaptiveNavItem(
        icon: LucideIcons.scanLine,
        selectedIcon: LucideIcons.scanLine,
        label: 'Scan QR',
        onTap: () async {
          final scanned = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const QrScannerPage()),
          );
          if (scanned == true) _loadStudentData();
        },
      ),
      AdaptiveNavItem(
        icon: LucideIcons.history,
        selectedIcon: LucideIcons.history,
        label: 'History',
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentHistoryPage()));
        },
      ),
      AdaptiveNavItem(
        icon: LucideIcons.userCircle2,
        selectedIcon: LucideIcons.userCircle2,
        label: 'Profile',
        onTap: () async {
          final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
          if (updated == true) _loadStudentData();
        },
      ),
    ];

    final contentWidget = _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.royalNavy))
        : RefreshIndicator(
            onRefresh: _loadStudentData,
            color: AppTheme.royalNavy,
            child: Scrollbar(
              controller: _scrollController,
              thumbVisibility: isDesktop,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  // Clean, Conflict-Free Pinned Sliver App Bar
                  SliverAppBar(
                    pinned: true,
                    floating: false,
                    backgroundColor: AppTheme.bgLight,
                    surfaceTintColor: Colors.transparent,
                    elevation: 0,
                    titleSpacing: 16,
                    title: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.borderLight),
                            boxShadow: AppTheme.softShadow,
                          ),
                          padding: const EdgeInsets.all(3),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: Image.asset('assets/images/du.png', fit: BoxFit.contain),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                user?.name ?? _student?.name ?? 'Student Portal',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.royalNavy,
                                ),
                              ),
                              Text(
                                _student != null && _student!.classRollNo.isNotEmpty
                                    ? 'Roll: ${_student!.classRollNo} • ${_student!.course} ${_student!.semesterDisplay}'
                                    : 'CCSA Dibrugarh University',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    actions: [
                      // Single Stylish Profile Button (Opens Settings / Profile Screen)
                      Padding(
                        padding: const EdgeInsets.only(right: 12),
                        child: Material(
                          color: AppTheme.royalNavy.withOpacity(0.08),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            mouseCursor: SystemMouseCursors.click,
                            onTap: () async {
                              final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
                              if (updated == true) _loadStudentData();
                            },
                            child: Container(
                              width: 40,
                              height: 40,
                              alignment: Alignment.center,
                              child: const Icon(LucideIcons.userCircle2, color: AppTheme.royalNavy, size: 22),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Main Content Body
                  SliverToBoxAdapter(
                    child: AdaptiveContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Incomplete Profile Alert Banner
                          if (isProfileIncomplete) ...[
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.amberWarningBg,
                                borderRadius: AppTheme.cardRadius,
                                border: Border.all(color: AppTheme.amberWarningBorder, width: 1.2),
                              ),
                              child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    const Icon(LucideIcons.alertCircle, color: Color(0xFFB45309), size: 24),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          MarqueeText(
                                            text: 'Complete Academic Profile',
                                            style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13.5, color: const Color(0xFFB45309)),
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            'Fill your Class Roll No and Semester to enable live attendance sync.',
                                            softWrap: true,
                                            maxLines: 2,
                                            style: GoogleFonts.inter(fontSize: 11.5, color: const Color(0xFF92400E)),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFB45309),
                                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                        shape: RoundedRectangleBorder(borderRadius: AppTheme.pillRadius),
                                      ),
                                      onPressed: () async {
                                        final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfilePage()));
                                        if (updated == true) _loadStudentData();
                                      },
                                      child: const Text('Complete', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
                                    ),
                                  ],
                                ),
                            ),
                            const SizedBox(height: 16),
                          ],

                          // Hero Attendance Overview Card (Classes instead of hours)
                          _buildHeroAttendanceCard(overallPercentage, totalClassesHeld, totalClassesAttended),
                          const SizedBox(height: 20),

                          // Quick Actions Bar: Scan, Attendance Logs, Security
                          _buildQuickActionsRow(context),
                          const SizedBox(height: 24),

                          // Visual Attendance Graph Analytics
                          if (_enrolledSubjects.isNotEmpty) ...[
                            AttendanceChartWidget(
                              title: 'Attendance by Subject',
                              items: chartItems,
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Subject List Breakdown
                          SectionHeader(
                            title: 'Subject Breakdown',
                            count: '${_enrolledSubjects.length}',
                          ),
                          const SizedBox(height: 12),
                          _buildSubjectList(),

                          const SizedBox(height: 32),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );

    return AdaptiveScaffold(
      title: 'Student Dashboard',
      selectedIndex: _navIndex,
      navItems: navItems,
      body: contentWidget,
    );
  }

  Widget _buildSubjectList() {
    final theme = Theme.of(context);

    if (_enrolledSubjects.isEmpty) {
      return const EmptyStateWidget(
        icon: LucideIcons.bookOpenCheck,
        title: 'No Enrolled Subjects Yet',
        subtitle: 'When professors create subjects for your semester batch, they will automatically appear here.',
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _enrolledSubjects.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final subject = _enrolledSubjects[index];
        final stats = _subjectStats[subject.id];
        final double pct = stats?['percentage'] ?? 100.0;
        final int total = stats?['total'] ?? 0;
        final int attended = stats?['attended'] ?? 0;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            mouseCursor: SystemMouseCursors.click,
            onTap: () => _showSubjectDetailModal(subject),
            borderRadius: AppTheme.cardRadius,
            splashColor: theme.colorScheme.primary.withOpacity(0.06),
            hoverColor: theme.colorScheme.primary.withOpacity(0.03),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: AppTheme.cardRadius,
                border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.7), width: 1.0),
                boxShadow: AppTheme.softShadow,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppTheme.royalNavy.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                subject.code,
                                style: GoogleFonts.sourceCodePro(fontSize: 11.5, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'Prof. ${subject.professorName}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          subject.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 14.5, color: AppTheme.royalNavy),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$attended / $total Classes Attended • Tap for session logs',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${pct.toStringAsFixed(1)}%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: pct >= 75 ? AppTheme.emeraldGreen : AppTheme.crimsonRose,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: pct >= 75 ? AppTheme.emeraldGreenBg : AppTheme.crimsonRoseBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          pct >= 75 ? 'Safe' : 'Shortage',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: pct >= 75 ? AppTheme.emeraldGreen : AppTheme.crimsonRose,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  const Icon(LucideIcons.chevronRight, size: 16, color: AppTheme.textSecondary),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeroAttendanceCard(double overallPercentage, int totalClassesHeld, int totalClassesAttended) {
    String statusLabel;
    Color statusTextColor;
    Color statusBgColor;
    Color statusBorderColor;

    if (overallPercentage >= 80.0) {
      statusLabel = 'Regular (≥80%)';
      statusTextColor = const Color(0xFF047857);
      statusBgColor = AppTheme.emeraldGreenBg;
      statusBorderColor = AppTheme.emeraldGreenBorder;
    } else if (overallPercentage >= 70.0) {
      statusLabel = 'NC (70%-80%)';
      statusTextColor = const Color(0xFFB45309);
      statusBgColor = AppTheme.amberWarningBg;
      statusBorderColor = AppTheme.amberWarningBorder;
    } else {
      statusLabel = 'DC (<70%)';
      statusTextColor = AppTheme.crimsonRose;
      statusBgColor = AppTheme.crimsonRoseBg;
      statusBorderColor = AppTheme.crimsonRoseBorder;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.borderLight, width: 1.0),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarqueeText(
                      text: 'Overall Attendance Summary',
                      style: GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                    ),
                    const SizedBox(height: 2),
                    MarqueeText(
                      text: 'Centre for Computer Science and Applications',
                      style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: statusBorderColor),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusTextColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              AttendanceGauge(
                percentage: overallPercentage,
                size: 104,
                strokeWidth: 9,
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildMetricRow('Total Classes', '$totalClassesHeld', LucideIcons.calendar),
                    const SizedBox(height: 6),
                    _buildMetricRow('Classes Attended', '$totalClassesAttended', LucideIcons.checkCircle2, color: AppTheme.emeraldGreen),
                    const SizedBox(height: 6),
                    _buildMetricRow('Classes Missed', '${totalClassesHeld - totalClassesAttended}', LucideIcons.xCircle, color: AppTheme.crimsonRose),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Primary Dynamic Action Pill: Simply "Scan"
          GPayActionPill(
            label: 'Scan',
            icon: LucideIcons.scanLine,
            onPressed: () async {
              final scanned = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerPage()),
              );
              if (scanned == true) _loadStudentData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsRow(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.borderLight, width: 1.0),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GPayQuickActionItem(
            icon: LucideIcons.scanLine,
            label: 'Scan',
            iconColor: AppTheme.royalNavy,
            onTap: () async {
              final scanned = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const QrScannerPage()),
              );
              if (scanned == true) _loadStudentData();
            },
          ),
          GPayQuickActionItem(
            icon: LucideIcons.history,
            label: 'History',
            iconColor: AppTheme.electricTeal,
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentHistoryPage()));
            },
          ),
          GPayQuickActionItem(
            icon: LucideIcons.refreshCw,
            label: 'Refresh',
            iconColor: AppTheme.indigoAccent,
            onTap: () {
              AppTheme.triggerLightHaptic();
              _loadStudentData();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, IconData icon, {Color? color}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: color ?? AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(label, style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700, color: color ?? AppTheme.royalNavy),
        ),
      ],
    );
  }
}
