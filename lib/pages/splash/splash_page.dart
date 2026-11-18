import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../auth/login_page.dart';
import '../faculty/faculty_dashboard_page.dart';
import '../student/student_dashboard_page.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _dotsFade;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _scaleAnimation = Tween<double>(begin: 0.78, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.7, curve: Curves.fastOutSlowIn),
      ),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.0, 0.65, curve: Curves.easeIn),
      ),
    );

    _dotsFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
      ),
    );

    _animController.forward();
    _checkAuthAndNavigate();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _checkAuthAndNavigate() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;

    final isLoggedIn = AuthService.instance.isLoggedIn;
    final isFaculty = AuthService.instance.isFaculty;

    Widget targetPage = const LoginPage();
    if (isLoggedIn) {
      targetPage = isFaculty ? const FacultyDashboardPage() : const StudentDashboardPage();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, animation, secondaryAnimation) => FadeTransition(
          opacity: animation,
          child: targetPage,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Soft doodle canvas backdrop
          Positioned.fill(
            child: Opacity(
              opacity: 0.5,
              child: CustomPaint(
                painter: _SplashBackdropPainter(),
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, child) {
                  return FadeTransition(
                    opacity: _fadeAnimation,
                    child: ScaleTransition(
                      scale: _scaleAnimation,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Dibrugarh University Logo with glow ring
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              Container(
                                width: 122,
                                height: 122,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppTheme.googleSky.withOpacity(0.4),
                                ),
                              ),
                              Container(
                                width: 106,
                                height: 106,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  border: Border.all(color: AppTheme.borderLight, width: 1.5),
                                  boxShadow: AppTheme.softShadow,
                                ),
                                padding: const EdgeInsets.all(10),
                                child: ClipOval(
                                  child: Image.asset(
                                    'assets/images/du.png',
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => const Icon(
                                      Icons.school_rounded,
                                      size: 44,
                                      color: AppTheme.royalNavy,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Brand Wordmark with Google-colored dot accents
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CCSAAS',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w800,
                                  color: AppTheme.royalNavy,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const _GoogleDots(height: 8, gap: 4),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Centre for Computer Science and Applications',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w500,
                              color: theme.colorScheme.onSurface.withOpacity(0.6),
                            ),
                          ),
                          Text(
                            'Dibrugarh University, Assam',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w400,
                              color: theme.colorScheme.onSurface.withOpacity(0.4),
                            ),
                          ),
                          const SizedBox(height: 48),

                          // Orbiting Google-colored loader
                          FadeTransition(
                            opacity: _dotsFade,
                            child: SizedBox(
                              width: 46,
                              height: 46,
                              child: AnimatedBuilder(
                                animation: _animController,
                                builder: (context, _) => CustomPaint(
                                  painter: _SplashOrbitPainter(progress: _animController.value),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          // Footer tagline
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: FadeTransition(
              opacity: _dotsFade,
              child: Column(
                children: [
                  Text(
                    'Smart Attendance • Dynamic QR',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textMuted,
                      letterSpacing: 0.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Google-blue/red/yellow/green tiny dot quartet.
class _GoogleDots extends StatelessWidget {
  final double height;
  final double gap;

  const _GoogleDots({required this.height, required this.gap});

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppTheme.googleBlue,
      AppTheme.googleRed,
      AppTheme.googleYellow,
      AppTheme.googleGreen,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < colors.length; i++) ...[
            if (i > 0) SizedBox(width: gap),
            Container(
              width: height,
              height: height,
              decoration: BoxDecoration(color: colors[i], shape: BoxShape.circle),
            ),
          ],
        ],
      ),
    );
  }
}

/// Rotating 4-color orbit loader for splash.
class _SplashOrbitPainter extends CustomPainter {
  final double progress;
  _SplashOrbitPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.32;
    final colors = [
      AppTheme.googleBlue,
      AppTheme.googleRed,
      AppTheme.googleYellow,
      AppTheme.googleGreen,
    ];
    for (int i = 0; i < 4; i++) {
      final angle = (progress + i / 4) * 2 * math.pi;
      final pos = c + Offset(math.cos(angle) * r, math.sin(angle) * r);
      canvas.drawCircle(pos, 3.4, Paint()..color = colors[i].withOpacity(0.9));
    }
    canvas.drawCircle(c, 2.4, Paint()..color = AppTheme.royalNavy.withOpacity(0.85));
  }

  @override
  bool shouldRepaint(_SplashOrbitPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Very soft scattered doodles behind the splash content.
class _SplashBackdropPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.royalNavy.withOpacity(0.06);

    const positions = [
      Offset(0.08, 0.14), Offset(0.85, 0.10), Offset(0.92, 0.62),
      Offset(0.10, 0.68), Offset(0.30, 0.05), Offset(0.65, 0.90),
      Offset(0.12, 0.40), Offset(0.88, 0.38),
    ];
    for (int i = 0; i < positions.length; i++) {
      final p = Offset(positions[i].dx * size.width, positions[i].dy * size.height);
      final r = 7.0 + (i % 3) * 3.0;
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate((i % 4) * 0.3);
      switch (i % 3) {
        case 0: // sparkle
          final path = Path()
            ..moveTo(0, -r)
            ..quadraticBezierTo(r * 0.18, -r * 0.18, r, 0)
            ..quadraticBezierTo(r * 0.18, r * 0.18, 0, r)
            ..quadraticBezierTo(-r * 0.18, r * 0.18, -r, 0)
            ..quadraticBezierTo(-r * 0.18, -r * 0.18, 0, -r);
          canvas.drawPath(path, paint);
          break;
        case 1: // circle
          canvas.drawCircle(Offset.zero, r * 0.7, paint);
          break;
        case 2: // plus
          canvas.drawLine(Offset(-r, 0), Offset(r, 0), paint);
          canvas.drawLine(Offset(0, -r), Offset(0, r), paint);
          break;
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_SplashBackdropPainter oldDelegate) => false;
}
