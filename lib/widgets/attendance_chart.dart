import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../theme/app_theme.dart';
import 'marquee_text.dart';

class AttendanceBarItem {
  final String label;
  final double percentage; // 0 to 100
  final int attended;
  final int total;
  final String? subtitle;

  const AttendanceBarItem({
    required this.label,
    required this.percentage,
    required this.attended,
    required this.total,
    this.subtitle,
  });
}

/// Material 3 Attendance Analytics Graph & Compliance Visualizer
class AttendanceChartWidget extends StatelessWidget {
  final String title;
  final List<AttendanceBarItem> items;
  final double threshold;

  const AttendanceChartWidget({
    super.key,
    required this.title,
    required this.items,
    this.threshold = 75.0,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppTheme.cardRadius,
          border: Border.all(color: AppTheme.borderLight),
        ),
        child: Center(
          child: Text(
            'No attendance records available for visualization yet.',
            style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ),
      );
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppTheme.royalNavy.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(LucideIcons.barChart3, size: 16, color: AppTheme.royalNavy),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: MarqueeText(
                        text: title,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.royalNavy,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bar List
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 14),
            itemBuilder: (context, index) {
              final item = items[index];
              final isSafe = item.percentage >= threshold;
              final Color barColor = isSafe ? AppTheme.emeraldGreen : AppTheme.crimsonRose;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          item.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.royalNavy,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${item.attended}/${item.total} classes (${item.percentage.toStringAsFixed(0)}%)',
                        style: GoogleFonts.inter(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: barColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Stack(
                    children: [
                      // Background Track
                      Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppTheme.borderLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      // Progress Bar
                      FractionallySizedBox(
                        widthFactor: (item.percentage / 100.0).clamp(0.0, 1.0),
                        child: Container(
                          height: 8,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: isSafe
                                  ? [const Color(0xFF10B981), const Color(0xFF059669)]
                                  : [const Color(0xFFF43F5E), const Color(0xFFE11D48)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
