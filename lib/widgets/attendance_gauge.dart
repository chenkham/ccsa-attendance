import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';

class AttendanceGauge extends StatelessWidget {
  final double percentage;
  final double size;
  final double strokeWidth;

  const AttendanceGauge({
    super.key,
    required this.percentage,
    this.size = 100,
    this.strokeWidth = 9,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: percentage.clamp(0.0, 100.0)),
      duration: AppTheme.motionSpring,
      curve: Curves.easeOutCubic,
      builder: (context, animatedValue, _) {
        final bool isSafe = animatedValue >= 80.0;
        final Color gaugeColor = isSafe ? AppTheme.emeraldGreen : AppTheme.crimsonRose;

        return Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: (animatedValue / 100).clamp(0.0, 1.0),
                strokeWidth: strokeWidth,
                strokeCap: StrokeCap.round,
                backgroundColor: AppTheme.borderLight,
                valueColor: AlwaysStoppedAnimation<Color>(gaugeColor),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${animatedValue.toStringAsFixed(1)}%',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: size * 0.19,
                    fontWeight: FontWeight.w800,
                    color: gaugeColor,
                    height: 1.1,
                  ),
                ),
                Text(
                  isSafe ? 'Eligible' : 'Shortage',
                  style: GoogleFonts.inter(
                    fontSize: size * 0.11,
                    fontWeight: FontWeight.w700,
                    color: isSafe ? const Color(0xFF047857) : AppTheme.crimsonRose,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
