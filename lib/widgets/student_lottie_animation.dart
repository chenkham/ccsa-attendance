import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import '../theme/app_theme.dart';

class StudentLottieAnimation extends StatelessWidget {
  final double height;
  final double width;

  const StudentLottieAnimation({
    super.key,
    this.height = 160,
    this.width = 160,
  });

  // Direct student animation json from Lottie host
  static const String _lottieUrl = 'https://assets5.lottiefiles.com/packages/lf20_1a8aoonq.json';

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: width,
      child: Lottie.network(
        _lottieUrl,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          // Offline fallback animated illustration
          return Container(
            decoration: BoxDecoration(
              color: AppTheme.royalNavy.withOpacity(0.06),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  border: Border.all(color: AppTheme.borderLight, width: 1.5),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Image.asset(
                  'assets/images/du.png',
                  width: 48,
                  height: 48,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        },
        frameBuilder: (context, child, composition) {
          if (composition == null) {
            return Center(
              child: SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: AppTheme.royalNavy.withOpacity(0.4),
                ),
              ),
            );
          }
          return child;
        },
      ),
    );
  }
}
