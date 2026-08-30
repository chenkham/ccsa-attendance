import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../../db/database_helper.dart';
import '../../services/api_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/custom_cards.dart';
import '../../widgets/responsive_layout.dart';

class StudentHistoryPage extends StatefulWidget {
  const StudentHistoryPage({super.key});

  @override
  State<StudentHistoryPage> createState() => _StudentHistoryPageState();
}

class _StudentHistoryPageState extends State<StudentHistoryPage> {
  List<Map<String, dynamic>> _attendanceTimeline = [];
  bool _isLoading = true;
  String _filter = 'All'; // 'All', 'Present', 'Absent'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final user = AuthService.instance.currentUser;
    var std = AuthService.instance.currentStudent;

    if (std == null && user != null) {
      std = await DatabaseHelper.instance.getStudentById(user.id);
      if (std == null && user.studentRollNo != null) {
        std = await DatabaseHelper.instance.getStudentByRollNo(user.studentRollNo!);
      }
    }

    if (std != null && user != null) {
      // 1. Query live sessions from Hostinger MySQL Cloud Database
      final cloudData = await ApiService.instance.getStudentAttendanceFromCloud(
        email: user.email,
        studentId: std.id,
      );

      if (cloudData != null && cloudData['sessions'] is List) {
        final cloudSessions = (cloudData['sessions'] as List).cast<Map<String, dynamic>>();
        if (mounted) {
          setState(() {
            _attendanceTimeline = cloudSessions;
            _isLoading = false;
          });
        }
        return;
      }

      // Offline fallback
      final db = await DatabaseHelper.instance.database;
      final records = await db.rawQuery('''
        SELECT r.*, s.subject_code, s.subject_name, s.session_date, s.is_lab, s.teacher_email
        FROM attendance_records r
        JOIN attendance_sessions s ON r.session_id = s.id
        WHERE r.student_id = ?
        ORDER BY s.session_date DESC
      ''', [std.id]);

      if (mounted) {
        setState(() {
          _attendanceTimeline = records;
          _isLoading = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final DateFormat df = DateFormat('EEE, dd MMM yyyy • hh:mm a');

    final filtered = _attendanceTimeline.where((item) {
      final status = (item['status'] as String? ?? '').toLowerCase();
      if (_filter == 'Present' && status != 'present') return false;
      if (_filter == 'Absent' && status == 'present') return false;

      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final code = (item['subject_code'] as String? ?? '').toLowerCase();
        final name = (item['subject_name'] as String? ?? '').toLowerCase();
        return code.contains(q) || name.contains(q);
      }
      return true;
    }).toList();

    int totalPresent = 0;
    for (var item in _attendanceTimeline) {
      if ((item['status'] as String? ?? '').toLowerCase() == 'present') {
        totalPresent++;
      }
    }
    final int totalClasses = _attendanceTimeline.length;
    final double pct = totalClasses > 0 ? (totalPresent / totalClasses) * 100 : 100.0;

    return Scaffold(
      backgroundColor: AppTheme.bgLight,
      appBar: AppBar(
        title: Text(
          'My Attendance History',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.royalNavy))
          : AdaptiveContainer(
              child: Column(
                children: [
                  // Overview Banner
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppTheme.cardRadius,
                      border: Border.all(color: AppTheme.borderLight),
                      boxShadow: AppTheme.softShadow,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              Text('Total Classes', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
                              const SizedBox(height: 2),
                              Text('$totalClasses', style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.royalNavy)),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 32, color: AppTheme.borderLight),
                        Expanded(
                          child: Column(
                            children: [
                              Text('Attended', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
                              const SizedBox(height: 2),
                              Text('$totalPresent', style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.emeraldGreen)),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 32, color: AppTheme.borderLight),
                        Expanded(
                          child: Column(
                            children: [
                              Text('Missed', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
                              const SizedBox(height: 2),
                              Text('${totalClasses - totalPresent}', style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w800, color: AppTheme.crimsonRose)),
                            ],
                          ),
                        ),
                        Container(width: 1, height: 32, color: AppTheme.borderLight),
                        Expanded(
                          child: Column(
                            children: [
                              Text('Overall %', style: GoogleFonts.inter(fontSize: 11.5, color: AppTheme.textSecondary)),
                              const SizedBox(height: 2),
                              Text('${pct.toStringAsFixed(0)}%', style: GoogleFonts.plusJakartaSans(fontSize: 19, fontWeight: FontWeight.w800, color: pct >= 75 ? AppTheme.emeraldGreen : AppTheme.crimsonRose)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Search and Filter Row
                  TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by subject code or name...',
                      prefixIcon: Icon(LucideIcons.search, size: 17, color: AppTheme.royalNavy),
                      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    ),
                    onChanged: (v) => setState(() => _searchQuery = v.trim()),
                  ),
                  const SizedBox(height: 10),

                  Row(
                    children: ['All', 'Present', 'Absent'].map((filter) {
                      final isSel = _filter == filter;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(filter),
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
                          onSelected: (_) => setState(() => _filter = filter),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 14),

                  // History List
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: EmptyStateWidget(
                              icon: LucideIcons.calendarX,
                              title: 'No Records Found',
                              subtitle: 'When classes are marked for your batch, session logs will appear here.',
                            ),
                          )
                        : ListView.separated(
                            physics: const BouncingScrollPhysics(),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final item = filtered[index];
                              final bool isPresent = (item['status'] as String? ?? '').toLowerCase() == 'present';
                              final date = item['session_date'] != null
                                  ? DateTime.tryParse(item['session_date']) ?? DateTime.now()
                                  : DateTime.now();

                              return Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: AppTheme.cardRadius,
                                  border: Border.all(color: AppTheme.borderLight),
                                  boxShadow: AppTheme.softShadow,
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 16,
                                      backgroundColor: isPresent ? AppTheme.emeraldGreenBg : AppTheme.crimsonRoseBg,
                                      child: Icon(
                                        isPresent ? LucideIcons.check : LucideIcons.x,
                                        size: 16,
                                        color: isPresent ? AppTheme.emeraldGreen : AppTheme.crimsonRose,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.royalNavy.withOpacity(0.08),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  item['subject_code'] ?? 'SUB',
                                                  style: GoogleFonts.sourceCodePro(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  item['subject_name'] ?? 'Class Session',
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13.5),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 3),
                                          Text(
                                            df.format(date),
                                            style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: isPresent ? AppTheme.emeraldGreenBg : AppTheme.crimsonRoseBg,
                                        borderRadius: BorderRadius.circular(6),
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
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
