import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../db/database_helper.dart';
import '../models/attendance_session.dart';
import '../models/subject.dart';
import '../theme/app_theme.dart';

class StudentAttendanceDialog extends StatelessWidget {
  final Subject subject;
  final Map<String, dynamic> stats;

  const StudentAttendanceDialog({
    super.key,
    required this.subject,
    required this.stats,
  });

  @override
  Widget build(BuildContext context) {
    final double pct = (stats['percentage'] as num?)?.toDouble() ?? 100.0;
    final int totalHeld = (stats['totalSessions'] ?? stats['total']) as int? ?? 0;
    final int totalAttended = (stats['attendedSessions'] ?? stats['attended']) as int? ?? 0;
    final int missed = (stats['missed'] as int?) ?? (totalHeld - totalAttended);
    final List history = (stats['history'] as List?) ?? [];

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.royalNavy.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(LucideIcons.bookOpen, color: AppTheme.royalNavy, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      subject.code,
                      style: GoogleFonts.sourceCodePro(fontSize: 12, fontWeight: FontWeight.w800, color: AppTheme.royalNavy),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.royalNavy.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.borderLight),
                      ),
                      child: Text(
                        '${pct.toStringAsFixed(1)}% ($totalAttended/$totalHeld classes)',
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.royalNavy,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subject.name,
                  style: GoogleFonts.plusJakartaSans(fontSize: 14.5, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.bgLight,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.borderLight),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Total Classes', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('$totalHeld classes', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.royalNavy)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Classes Attended', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('$totalAttended classes', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF047857))),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Classes Missed', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                        Text('$missed classes', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.crimsonRose)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              Text(
                'Session-Wise Breakdown Log',
                style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13, color: AppTheme.royalNavy),
              ),
              const SizedBox(height: 8),

              if (history.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text('No attendance lectures logged yet.', style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary)),
                  ),
                )
              else
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: history.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: AppTheme.borderSubtle),
                  itemBuilder: (context, index) {
                    final item = history[index];
                    final bool isPresent = item['status'] == 'present';
                    final dateStr = item['session_date'] != null
                        ? DateFormat('dd MMM yyyy • hh:mm a').format(DateTime.tryParse(item['session_date']) ?? DateTime.now())
                        : 'Session';

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: isPresent ? AppTheme.emeraldGreenBg : AppTheme.crimsonRoseBg,
                            child: Icon(
                              isPresent ? LucideIcons.check : LucideIcons.x,
                              size: 13,
                              color: isPresent ? AppTheme.emeraldGreen : AppTheme.crimsonRose,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              dateStr,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                            decoration: BoxDecoration(
                              color: isPresent ? AppTheme.emeraldGreenBg : AppTheme.crimsonRoseBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isPresent ? 'PRESENT' : 'ABSENT',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: isPresent ? const Color(0xFF047857) : AppTheme.crimsonRose,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.royalNavy,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class StudentAttendanceDetailSheet extends StatefulWidget {
  final String studentId;
  final Subject subject;

  const StudentAttendanceDetailSheet({
    super.key,
    required this.studentId,
    required this.subject,
  });

  static Future<void> show(BuildContext context, {required String studentId, required Subject subject}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StudentAttendanceDetailSheet(studentId: studentId, subject: subject),
    );
  }

  @override
  State<StudentAttendanceDetailSheet> createState() => _StudentAttendanceDetailSheetState();
}

class _StudentAttendanceDetailSheetState extends State<StudentAttendanceDetailSheet> {
  List<AttendanceSession> _sessions = [];
  Map<String, AttendanceRecord?> _sessionRecords = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetail();
  }

  Future<void> _loadDetail() async {
    setState(() => _isLoading = true);
    final sess = await DatabaseHelper.instance.getSessionsForSubject(widget.subject.id);
    sess.sort((a, b) => b.sessionDate.compareTo(a.sessionDate));

    Map<String, AttendanceRecord?> recs = {};
    for (var s in sess) {
      final records = await DatabaseHelper.instance.getRecordsForSession(s.id);
      try {
        final r = records.firstWhere((rec) => rec.studentId == widget.studentId);
        recs[s.id] = r;
      } catch (_) {
        recs[s.id] = null;
      }
    }

    if (mounted) {
      setState(() {
        _sessions = sess;
        _sessionRecords = recs;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    int attendedCount = 0;
    for (var s in _sessions) {
      final r = _sessionRecords[s.id];
      if (r?.status == 'present') {
        attendedCount++;
      }
    }

    final double pct = _sessions.isNotEmpty ? (attendedCount / _sessions.length) * 100 : 0.0;
    final bool isEligible = pct >= 80.0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: AppTheme.bgLight,
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
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
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
                              widget.subject.code,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: AppTheme.royalNavy,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Session Logs',
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.subject.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(LucideIcons.x, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.borderLight),
                boxShadow: AppTheme.softShadow,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text('Total Lectures', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 2),
                      Text('${_sessions.length}', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.royalNavy)),
                    ],
                  ),
                  Container(width: 1, height: 28, color: AppTheme.borderLight),
                  Column(
                    children: [
                      Text('Attended', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 2),
                      Text('$attendedCount', style: GoogleFonts.plusJakartaSans(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.emeraldGreen)),
                    ],
                  ),
                  Container(width: 1, height: 28, color: AppTheme.borderLight),
                  Column(
                    children: [
                      Text('NEP %', style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary)),
                      const SizedBox(height: 2),
                      Text(
                        '${pct.toStringAsFixed(0)}%',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: isEligible ? AppTheme.emeraldGreen : AppTheme.crimsonRose,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.royalNavy))
                : _sessions.isEmpty
                    ? Center(
                        child: Text(
                          'No attendance sessions conducted yet for this subject.',
                          style: GoogleFonts.inter(color: AppTheme.textSecondary, fontSize: 13),
                        ),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        itemCount: _sessions.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final sess = _sessions[index];
                          final rec = _sessionRecords[sess.id];
                          final bool isPresent = rec?.status == 'present';
                          final DateFormat df = DateFormat('EEE, dd MMM yyyy • hh:mm a');

                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppTheme.borderLight),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: isPresent ? AppTheme.emeraldGreenBg : AppTheme.crimsonRoseBg,
                                  child: Icon(
                                    isPresent ? LucideIcons.check : LucideIcons.x,
                                    size: 14,
                                    color: isPresent ? AppTheme.emeraldGreen : AppTheme.crimsonRose,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        df.format(sess.sessionDate),
                                        style: GoogleFonts.inter(fontSize: 12.5, fontWeight: FontWeight.w600),
                                      ),
                                      Text(
                                        sess.isLab ? 'Lab Session (2h credit)' : 'Theory Session (1h credit)',
                                        style: GoogleFonts.inter(fontSize: 11, color: AppTheme.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: isPresent ? AppTheme.emeraldGreenBg : AppTheme.crimsonRoseBg,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: isPresent ? AppTheme.emeraldGreenBorder : AppTheme.crimsonRoseBorder,
                                    ),
                                  ),
                                  child: Text(
                                    isPresent ? 'PRESENT' : 'ABSENT',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w800,
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
    );
  }
}
