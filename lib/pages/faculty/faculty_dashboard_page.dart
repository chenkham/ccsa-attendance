import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../db/database_helper.dart';
import '../../models/subject.dart';
import '../../models/attendance_session.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../services/csv_export_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/attendance_chart.dart';
import '../../widgets/custom_cards.dart';
import '../../widgets/responsive_layout.dart';
import '../common/settings_page.dart';
import 'create_subject_page.dart';
import 'dynamic_qr_session_page.dart';
import 'session_history_page.dart';
import 'subject_details_page.dart';

class FacultyDashboardPage extends StatefulWidget {
  const FacultyDashboardPage({super.key});

  @override
  State<FacultyDashboardPage> createState() => _FacultyDashboardPageState();
}

class _FacultyDashboardPageState extends State<FacultyDashboardPage> {
  List<Subject> _subjects = [];
  List<AttendanceSession> _sessions = [];
  Map<String, int> _subjectSessionCounts = {};
  Map<String, int> _subjectPresentCounts = {};
  bool _isLoading = true;
  String _selectedFilter = 'All'; // 'All', 'MCA', 'BCA', 'PGDCA'
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  int _navIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final user = AuthService.instance.currentUser;
    final email = user?.email ?? 'faculty@ccsa.du.ac.in';

    List<Subject> subs = [];
    List<AttendanceSession> sess = [];

    try {
      // 1. Fetch live state from Hostinger MySQL
      final cloudSubs = await ApiService.instance.getFacultySubjects(email);
      final cloudSess = await ApiService.instance.getFacultySessions(teacherEmail: email);

      if (cloudSubs.isNotEmpty || cloudSess.isNotEmpty) {
        subs = cloudSubs;
        sess = cloudSess;

        // Reconcile local SQLite cache (safe on mobile/desktop, ignored on web)
        try {
          final currentLocalSubs = await DatabaseHelper.instance.getSubjectsByTeacher(email);
          final cloudSubIds = cloudSubs.map((s) => s.id).toSet();
          for (var local in currentLocalSubs) {
            if (!cloudSubIds.contains(local.id)) {
              await DatabaseHelper.instance.deleteSubject(local.id);
            }
          }
          for (var s in cloudSubs) {
            await DatabaseHelper.instance.insertSubject(s);
          }
        } catch (e) {
          debugPrint('Local SQLite cache sync skipped: $e');
        }
      } else {
        try {
          subs = await DatabaseHelper.instance.getSubjectsByTeacher(email);
          sess = await DatabaseHelper.instance.getAllSessionsForTeacher(email);
        } catch (_) {}
      }
    } catch (e) {
      debugPrint('Dashboard data load error: $e');
    } finally {
      Map<String, int> sessCounts = {};
      Map<String, int> presCounts = {};

      for (var s in sess) {
        sessCounts[s.subjectId] = (sessCounts[s.subjectId] ?? 0) + 1;
        presCounts[s.subjectId] = (presCounts[s.subjectId] ?? 0) + s.totalPresent;
      }

      if (mounted) {
        setState(() {
          _subjects = subs;
          _sessions = sess;
          _subjectSessionCounts = sessCounts;
          _subjectPresentCounts = presCounts;
          _isLoading = false;
        });
      }
    }
  }

  void _exportAllCsv() async {
    AppTheme.triggerLightHaptic();
    if (_subjects.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No subjects available to export.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting attendance records for ${_subjects.length} subjects...'),
        behavior: SnackBarBehavior.floating,
      ),
    );

    for (var subject in _subjects) {
      await CsvExportService.instance.exportSubjectCsv(subject);
    }

    if (mounted) {
      AppTheme.triggerSuccessHaptic();
    }
  }

  void _exportSubjectCsv(Subject subject) {
    CsvExportService.instance.showExportDialog(context: context, subject: subject);
  }

  void _deleteSubject(Subject subject) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: AppTheme.cardRadius),
        title: Row(
          children: [
            const Icon(LucideIcons.alertTriangle, color: AppTheme.crimsonRose, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Delete Subject?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 16),
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${subject.code} (${subject.name})? All past session logs will also be permanently deleted.',
          style: GoogleFonts.inter(fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: AppTheme.textSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.crimsonRose,
              shape: RoundedRectangleBorder(borderRadius: AppTheme.pillRadius),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await DatabaseHelper.instance.deleteSubject(subject.id);
      await ApiService.instance.deleteSubject(subject.id);
      AppTheme.triggerSuccessHaptic();
      _loadDashboardData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final isWide = Responsive.isWide(context);
    final isDesktop = Responsive.isDesktop(context);

    final filteredSubjects = _subjects.where((s) {
      if (_selectedFilter != 'All' && s.course != _selectedFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        return s.name.toLowerCase().contains(q) || s.code.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    int totalStudentTurnout = 0;
    for (var s in _sessions) {
      totalStudentTurnout += s.totalPresent;
    }

    final chartItems = _subjects.map((sub) {
      final totalClasses = _subjectSessionCounts[sub.id] ?? 0;
      final enrolled = sub.enrolledStudentIds.length;
      final totalPossible = totalClasses * (enrolled > 0 ? enrolled : 1);
      final presentTotal = _subjectPresentCounts[sub.id] ?? 0;
      final pct = totalPossible > 0 ? (presentTotal / totalPossible) * 100 : 100.0;

      return AttendanceBarItem(
        label: '${sub.code} - ${sub.name}',
        percentage: pct.clamp(0.0, 100.0),
        attended: presentTotal,
        total: totalPossible > 0 ? totalPossible : enrolled,
      );
    }).toList();

    final navItems = [
      AdaptiveNavItem(
        icon: LucideIcons.layoutDashboard,
        selectedIcon: LucideIcons.layoutDashboard,
        label: 'Dashboard',
        onTap: () => setState(() => _navIndex = 0),
      ),
      AdaptiveNavItem(
        icon: LucideIcons.plusCircle,
        selectedIcon: LucideIcons.plusCircle,
        label: 'Add Subject',
        onTap: () async {
          final created = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const CreateSubjectPage()),
          );
          if (created == true) _loadDashboardData();
        },
      ),
      AdaptiveNavItem(
        icon: LucideIcons.history,
        selectedIcon: LucideIcons.history,
        label: 'History',
        onTap: () {
          if (_subjects.isNotEmpty) {
            Navigator.push(context, MaterialPageRoute(builder: (_) => SessionHistoryPage(subject: _subjects.first)));
          }
        },
      ),
      AdaptiveNavItem(
        icon: LucideIcons.fileSpreadsheet,
        selectedIcon: LucideIcons.fileSpreadsheet,
        label: 'Export All',
        onTap: _exportAllCsv,
      ),
      AdaptiveNavItem(
        icon: LucideIcons.userCircle2,
        selectedIcon: LucideIcons.userCircle2,
        label: 'Profile',
        onTap: () async {
          final updated = await Navigator.push(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
          if (updated == true) _loadDashboardData();
        },
      ),
    ];

    final contentWidget = _isLoading
        ? const Center(child: CircularProgressIndicator(color: AppTheme.royalNavy))
        : RefreshIndicator(
            onRefresh: _loadDashboardData,
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
                                user?.name ?? 'Faculty Portal',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.royalNavy,
                                ),
                              ),
                              Text(
                                user?.designation ?? 'CCSA Faculty Member',
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
                              if (updated == true) _loadDashboardData();
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

                  // Main Dashboard Content
                  SliverToBoxAdapter(
                    child: AdaptiveContainer(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 3-Column Metric Highlights (Classes instead of hours)
                          _buildMetricsOverview(totalStudentTurnout),
                          const SizedBox(height: 20),

                          // Quick Actions Bar (3 Items: Add Subject, Session Logs, Export All)
                          _buildQuickActionsRow(context),
                          const SizedBox(height: 24),

                          // Visual Attendance Graph Analytics
                          if (_subjects.isNotEmpty) ...[
                            AttendanceChartWidget(
                              title: 'Student Turnout & Subject Compliance',
                              items: chartItems,
                            ),
                            const SizedBox(height: 24),
                          ],

                          // Section Header: My Assigned Subjects
                          SectionHeader(
                            title: 'My Assigned Subjects',
                            count: '${filteredSubjects.length}',
                            trailing: TextButton.icon(
                              onPressed: () async {
                                final created = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CreateSubjectPage()),
                                );
                                if (created == true) _loadDashboardData();
                              },
                              icon: const Icon(LucideIcons.plus, size: 14, color: AppTheme.royalNavy),
                              label: Text(
                                'Add Subject',
                                style: GoogleFonts.inter(fontWeight: FontWeight.w700, fontSize: 12.5, color: AppTheme.royalNavy),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Search Bar & Filter Chips
                          TextField(
                            controller: _searchController,
                            decoration: const InputDecoration(
                              hintText: 'Search subjects by title or code (e.g. MCA-201)...',
                              prefixIcon: Icon(LucideIcons.search, size: 17, color: AppTheme.royalNavy),
                              contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            ),
                            onChanged: (val) => setState(() => _searchQuery = val),
                          ),
                          const SizedBox(height: 12),

                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            child: Row(
                              children: ['All', 'MCA', 'BCA', 'PGDCA'].map((filter) {
                                final isSel = _selectedFilter == filter;
                                return Padding(
                                  padding: const EdgeInsets.only(right: 8),
                                  child: ChoiceChip(
                                    label: Text(filter == 'All' ? 'All Programs' : filter),
                                    selected: isSel,
                                    selectedColor: AppTheme.royalNavy,
                                    backgroundColor: Colors.white,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: AppTheme.pillRadius,
                                      side: BorderSide(color: isSel ? AppTheme.royalNavy : AppTheme.borderLight),
                                    ),
                                    labelStyle: GoogleFonts.inter(
                                      color: isSel ? Colors.white : AppTheme.textSecondary,
                                      fontWeight: isSel ? FontWeight.w700 : FontWeight.w500,
                                      fontSize: 12,
                                    ),
                                    onSelected: (_) => setState(() => _selectedFilter = filter),
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Subject Cards: Adaptive Grid on Desktop/Tablet vs Column on Mobile
                          if (filteredSubjects.isEmpty)
                            EmptyStateWidget(
                              icon: LucideIcons.bookX,
                              title: 'No Subjects Found',
                              subtitle: 'Tap "Add Subject" to create a new subject course and enroll student batches.',
                              buttonLabel: 'Add New Subject',
                              onButtonPressed: () async {
                                final created = await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (_) => const CreateSubjectPage()),
                                );
                                if (created == true) _loadDashboardData();
                              },
                            )
                          else if (isWide)
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isDesktop ? 2 : 2,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                mainAxisExtent: 198,
                              ),
                              itemCount: filteredSubjects.length,
                              itemBuilder: (context, index) {
                                final subject = filteredSubjects[index];
                                return _buildSubjectCard(subject);
                              },
                            )
                          else
                            ListView.separated(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              itemCount: filteredSubjects.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 14),
                              itemBuilder: (context, index) {
                                final subject = filteredSubjects[index];
                                return _buildSubjectCard(subject);
                              },
                            ),
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
      title: 'Faculty Dashboard',
      selectedIndex: _navIndex,
      navItems: navItems,
      body: contentWidget,
    );
  }

  Widget _buildMetricsOverview(int totalStudentTurnout) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: AppTheme.cardRadius,
        border: Border.all(color: AppTheme.borderLight, width: 1.0),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              children: [
                Text('Active Subjects', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text('${_subjects.length}', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.royalNavy)),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: AppTheme.borderLight),
          Expanded(
            child: Column(
              children: [
                Text('Total Classes', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text('${_sessions.length}', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.electricTeal)),
              ],
            ),
          ),
          Container(width: 1, height: 36, color: AppTheme.borderLight),
          Expanded(
            child: Column(
              children: [
                Text('Total Present', maxLines: 1, overflow: TextOverflow.ellipsis, style: GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                const SizedBox(height: 4),
                Text('$totalStudentTurnout', style: GoogleFonts.plusJakartaSans(fontSize: 22, fontWeight: FontWeight.w800, color: AppTheme.emeraldGreen)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// 3 Quick Actions: Add Subject, Session Logs, Export All
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
            icon: LucideIcons.plus,
            label: 'Add Subject',
            iconColor: AppTheme.royalNavy,
            onTap: () async {
              final created = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CreateSubjectPage()),
              );
              if (created == true) _loadDashboardData();
            },
          ),
          GPayQuickActionItem(
            icon: LucideIcons.history,
            label: 'Session Logs',
            iconColor: AppTheme.electricTeal,
            onTap: () {
              if (_subjects.isNotEmpty) {
                Navigator.push(context, MaterialPageRoute(builder: (_) => SessionHistoryPage(subject: _subjects.first)));
              }
            },
          ),
          GPayQuickActionItem(
            icon: LucideIcons.fileSpreadsheet,
            label: 'Export All',
            iconColor: AppTheme.emeraldGreen,
            onTap: _exportAllCsv,
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectCard(Subject subject) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        mouseCursor: SystemMouseCursors.click,
        onTap: () {
          AppTheme.triggerLightHaptic();
          Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectDetailsPage(subject: subject)));
        },
        borderRadius: AppTheme.cardRadius,
        splashColor: theme.colorScheme.primary.withOpacity(0.06),
        hoverColor: theme.colorScheme.primary.withOpacity(0.03),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppTheme.cardRadius,
            border: Border.all(color: theme.colorScheme.outlineVariant.withOpacity(0.7), width: 1.0),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
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
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: AppTheme.electricTealBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${subject.course} ${subject.semesterDisplay}',
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppTheme.electricTeal),
                        ),
                      ),
                      if (subject.geofenceEnabled) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3.5),
                          decoration: BoxDecoration(
                            color: AppTheme.emeraldGreenBg,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(LucideIcons.mapPin, size: 10, color: Color(0xFF047857)),
                              const SizedBox(width: 3),
                              Text('${subject.radiusMeters.toInt()}m GPS', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Color(0xFF047857))),
                            ],
                          ),
                        ),
                      ],
                      const Spacer(),
                      PopupMenuButton<String>(
                        icon: const Icon(LucideIcons.moreVertical, size: 18, color: AppTheme.textSecondary),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 4,
                        onSelected: (val) {
                          if (val == 'details') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => SubjectDetailsPage(subject: subject)));
                          } else if (val == 'history') {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => SessionHistoryPage(subject: subject)));
                          } else if (val == 'export') {
                            _exportSubjectCsv(subject);
                          } else if (val == 'delete') {
                            _deleteSubject(subject);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'details', child: Row(children: [Icon(LucideIcons.info, size: 16), SizedBox(width: 8), Text('Subject Details')])),
                          PopupMenuItem(value: 'history', child: Row(children: [Icon(LucideIcons.history, size: 16), SizedBox(width: 8), Text('Session History')])),
                          PopupMenuItem(value: 'export', child: Row(children: [Icon(LucideIcons.fileSpreadsheet, size: 16), SizedBox(width: 8), Text('Export CSV Sheet')])),
                          PopupMenuItem(value: 'delete', child: Row(children: [Icon(LucideIcons.trash2, size: 16, color: AppTheme.crimsonRose), SizedBox(width: 8), Text('Delete Subject', style: TextStyle(color: AppTheme.crimsonRose))])),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    subject.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 15.5, color: AppTheme.royalNavy),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Batch: ${subject.batchLabel} • ${subject.enrolledStudentIds.length} Enrolled Students',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Action Pill
              GPayActionPill(
                label: 'Take Attendance',
                icon: LucideIcons.qrCode,
                height: 44,
                onPressed: () async {
                  final taken = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => DynamicQrSessionPage(subject: subject)),
                  );
                  if (taken == true) _loadDashboardData();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
