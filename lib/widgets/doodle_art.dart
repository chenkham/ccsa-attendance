import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ============================================================================
/// CCSA Expressive — Google Doodle Art Vector Library
/// Hand-drawn-inspired vector scenes and accents rendered with CustomPainter.
/// Zero external assets: everything is drawn with canvas primitives.
/// ============================================================================

/// A soft, scattered doodle pattern (stars, squiggles, sparkles, QR dots,
/// plus-marks, graduation caps) painted inside a header hero surface.
class DoodlePatternPainter extends CustomPainter {
  final Color ink;
  final double opacity;
  final int seed;

  DoodlePatternPainter({
    required this.ink,
    this.opacity = 0.10,
    this.seed = 7,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(seed);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = ink.withOpacity(opacity);

    const glyphs = 18;
    for (int i = 0; i < glyphs; i++) {
      final dx = rng.nextDouble() * size.width;
      final dy = rng.nextDouble() * size.height;
      final r = 5.0 + rng.nextDouble() * 6.0;
      final kind = rng.nextInt(6);
      canvas.save();
      canvas.translate(dx, dy);
      canvas.rotate((rng.nextDouble() - 0.5) * 0.9);
      switch (kind) {
        case 0: // four-point sparkle
          _paintSparkle(canvas, paint, r);
          break;
        case 1: // squiggle wave
          _paintSquiggle(canvas, paint, r * 2.2, r);
          break;
        case 2: // circle / bubble
          canvas.drawCircle(Offset.zero, r, paint);
          break;
        case 3: // plus mark
          _paintPlus(canvas, paint, r);
          break;
        case 4: // QR corner dot square
          _paintQrCorner(canvas, paint, r);
          break;
        case 5: // graduation cap doodle
          _paintCap(canvas, paint, r);
          break;
      }
      canvas.restore();
    }
  }

  void _paintSparkle(Canvas canvas, Paint paint, double r) {
    final path = Path()
      ..moveTo(0, -r)
      ..quadraticBezierTo(r * 0.18, -r * 0.18, r, 0)
      ..quadraticBezierTo(r * 0.18, r * 0.18, 0, r)
      ..quadraticBezierTo(-r * 0.18, r * 0.18, -r, 0)
      ..quadraticBezierTo(-r * 0.18, -r * 0.18, 0, -r);
    canvas.drawPath(path, paint);
  }

  void _paintSquiggle(Canvas canvas, Paint paint, double w, double h) {
    final path = Path()
      ..moveTo(-w / 2, 0)
      ..cubicTo(-w / 4, -h, -w / 8, h, 0, 0)
      ..cubicTo(w / 8, -h, w / 4, h, w / 2, 0);
    canvas.drawPath(path, paint);
  }

  void _paintPlus(Canvas canvas, Paint paint, double r) {
    canvas.drawLine(Offset(-r, 0), Offset(r, 0), paint);
    canvas.drawLine(Offset(0, -r), Offset(0, r), paint);
  }

  void _paintQrCorner(Canvas canvas, Paint paint, double r) {
    final rect = Rect.fromCenter(center: Offset.zero, width: r * 1.6, height: r * 1.6);
    final path = Path()
      ..moveTo(rect.left, rect.bottom)
      ..lineTo(rect.left, rect.top)
      ..lineTo(rect.right, rect.top);
    canvas.drawPath(path, paint);
    canvas.drawCircle(Offset(rect.right - r * 0.35, rect.bottom - r * 0.35), r * 0.28, paint);
  }

  void _paintCap(Canvas canvas, Paint paint, double r) {
    final path = Path()
      ..moveTo(-r * 1.4, 0)
      ..lineTo(0, -r * 0.7)
      ..lineTo(r * 1.4, 0)
      ..lineTo(0, r * 0.7)
      ..close();
    canvas.drawPath(path, paint);
    canvas.drawLine(const Offset(0, 0), Offset(0, r * 1.2), paint);
    canvas.drawLine(Offset(0, r * 1.2), Offset(r * 0.8, r * 0.9), paint);
  }

  @override
  bool shouldRepaint(DoodlePatternPainter oldDelegate) =>
      oldDelegate.ink != ink || oldDelegate.seed != seed || oldDelegate.opacity != opacity;
}

/// Scenarios for [DoodleEmptyArt] vector scenes.
enum DoodleScene {
  qrFrame, // scanning / no live session
  openBook, // no subjects
  clipboardCheck, // all caught up / empty history
  magnifier, // search found nothing
  calendar, // no upcoming classes
  wifiOff, // offline / connection issues
  rocket, // get started / create first
  shieldCheck, // security / all good
}

/// A delightful hand-drawn-style scene used in empty states.
/// Composed of layered canvas primitives in the Google accent palette.
class DoodleEmptyArt extends StatelessWidget {
  final DoodleScene scene;
  final double size;

  const DoodleEmptyArt({super.key, required this.scene, this.size = 150});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(painter: _DoodleScenePainter(scene: scene)),
    );
  }
}

class _DoodleScenePainter extends CustomPainter {
  final DoodleScene scene;
  _DoodleScenePainter({required this.scene});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final s = size.width;

    // Soft backdrop blob
    final blobPaint = Paint()..style = PaintingStyle.fill;
    canvas.drawCircle(c + Offset(0, s * 0.02), s * 0.34, blobPaint..color = AppTheme.googleSky.withOpacity(0.5));
    canvas.drawCircle(c + Offset(-s * 0.20, -s * 0.18), s * 0.09, blobPaint..color = AppTheme.googleLemon.withOpacity(0.9));
    canvas.drawCircle(c + Offset(s * 0.24, -s * 0.10), s * 0.06, blobPaint..color = AppTheme.googleBlush.withOpacity(0.9));

    final ink = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppTheme.royalNavy;

    final fill = Paint()..style = PaintingStyle.fill;

    switch (scene) {
      case DoodleScene.qrFrame:
        _qrFrame(canvas, c, s, ink, fill);
        break;
      case DoodleScene.openBook:
        _openBook(canvas, c, s, ink, fill);
        break;
      case DoodleScene.clipboardCheck:
        _clipboard(canvas, c, s, ink, fill);
        break;
      case DoodleScene.magnifier:
        _magnifier(canvas, c, s, ink, fill);
        break;
      case DoodleScene.calendar:
        _calendar(canvas, c, s, ink, fill);
        break;
      case DoodleScene.wifiOff:
        _wifiOff(canvas, c, s, ink, fill);
        break;
      case DoodleScene.rocket:
        _rocket(canvas, c, s, ink, fill);
        break;
      case DoodleScene.shieldCheck:
        _shield(canvas, c, s, ink, fill);
        break;
    }
  }

  void _sparkles(Canvas canvas, double s, Offset center, Paint paint) {
    final sp = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.03
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.googleYellow;
    for (final o in [Offset(-s * 0.30, -s * 0.30), Offset(s * 0.32, -s * 0.26), Offset(s * 0.30, s * 0.30)]) {
      final r = s * 0.06;
      final p = Path()
        ..moveTo(center.dx + o.dx, center.dy + o.dy - r)
        ..quadraticBezierTo(center.dx + o.dx + r * 0.16, center.dy + o.dy - r * 0.16, center.dx + o.dx + r, center.dy + o.dy)
        ..quadraticBezierTo(center.dx + o.dx + r * 0.16, center.dy + o.dy + r * 0.16, center.dx + o.dx, center.dy + o.dy + r)
        ..quadraticBezierTo(center.dx + o.dx - r * 0.16, center.dy + o.dy + r * 0.16, center.dx + o.dx - r, center.dy + o.dy)
        ..quadraticBezierTo(center.dx + o.dx - r * 0.16, center.dy + o.dy - r * 0.16, center.dx + o.dx, center.dy + o.dy - r);
      canvas.drawPath(p, sp);
    }
  }

  void _qrFrame(Canvas canvas, Offset c, double s, Paint ink, Paint fill) {
    final half = s * 0.24;
    final rect = Rect.fromCenter(center: c, width: half * 2, height: half * 2);
    final r = Radius.circular(s * 0.06);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, r), fill..color = Colors.white);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, r), ink);

    // Three QR eyes
    final eye = half * 0.34;
    for (final o in [
      Offset(-half + eye, -half + eye),
      Offset(half - eye, -half + eye),
      Offset(-half + eye, half - eye),
    ]) {
      final eRect = Rect.fromCenter(center: c + o, width: eye * 1.7, height: eye * 1.7);
      canvas.drawRRect(RRect.fromRectAndRadius(eRect, Radius.circular(eye * 0.5)), ink);
      canvas.drawCircle(c + o, eye * 0.45, fill..color = AppTheme.royalNavy);
    }
    // Scan beam + data dots
    final beam = Rect.fromLTWH(rect.left, c.dy - s * 0.015, rect.width, s * 0.03);
    canvas.drawRRect(RRect.fromRectAndRadius(beam, const Radius.circular(4)), fill..color = AppTheme.electricTeal.withOpacity(0.9));
    for (final o in [
      Offset(half - eye * 0.6, half - eye),
      Offset(half - eye * 1.4, half - eye * 1.8),
      Offset(half - eye * 0.5, half - eye * 2.2),
    ]) {
      canvas.drawCircle(c + o, s * 0.018, fill..color = AppTheme.royalNavy);
    }
    _sparkles(canvas, s, c, ink);
  }

  void _openBook(Canvas canvas, Offset c, double s, Paint ink, Paint fill) {
    final w = s * 0.30;
    final h = s * 0.20;
    final spine = Offset(c.dx, c.dy + s * 0.10);
    // Left page
    final left = Path()
      ..moveTo(spine.dx, spine.dy)
      ..quadraticBezierTo(spine.dx - w * 0.6, spine.dy - h * 0.55, spine.dx - w, spine.dy - h * 0.32)
      ..lineTo(spine.dx - w, spine.dy + h * 0.55)
      ..quadraticBezierTo(spine.dx - w * 0.6, spine.dy + h * 0.34, spine.dx, spine.dy + h * 0.62)
      ..close();
    // Right page
    final right = Path()
      ..moveTo(spine.dx, spine.dy)
      ..quadraticBezierTo(spine.dx + w * 0.6, spine.dy - h * 0.55, spine.dx + w, spine.dy - h * 0.32)
      ..lineTo(spine.dx + w, spine.dy + h * 0.55)
      ..quadraticBezierTo(spine.dx + w * 0.6, spine.dy + h * 0.34, spine.dx, spine.dy + h * 0.62)
      ..close();
    canvas.drawPath(left, fill..color = Colors.white);
    canvas.drawPath(right, fill..color = AppTheme.googleSky.withOpacity(0.45));
    canvas.drawPath(left, ink);
    canvas.drawPath(right, ink);
    canvas.drawLine(spine, spine + Offset(0, h * 0.62), ink);
    // Text lines
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.022
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.textMuted;
    for (int i = 0; i < 3; i++) {
      final y = spine.dy - h * 0.08 + i * h * 0.22;
      canvas.drawLine(Offset(spine.dx - w * 0.82, y), Offset(spine.dx - w * 0.25, y - h * 0.12), line);
      canvas.drawLine(Offset(spine.dx + w * 0.25, y - h * 0.12), Offset(spine.dx + w * 0.82, y), line);
    }
    _sparkles(canvas, s, c, ink);
  }

  void _clipboard(Canvas canvas, Offset c, double s, Paint ink, Paint fill) {
    final w = s * 0.30;
    final h = s * 0.38;
    final rect = Rect.fromCenter(center: c, width: w * 2, height: h * 2);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.05));
    canvas.drawRRect(rr, fill..color = Colors.white);
    canvas.drawRRect(rr, ink);
    // Clip
    final clip = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(c.dx, rect.top), width: w * 0.7, height: s * 0.09),
      Radius.circular(s * 0.04),
    );
    canvas.drawRRect(clip, fill..color = AppTheme.googleYellow.withOpacity(0.95));
    canvas.drawRRect(clip, ink);
    // Check rows
    final checkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.032
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppTheme.googleGreen;
    for (int i = 0; i < 3; i++) {
      final y = rect.top + h * 0.55 + i * h * 0.62;
      final p = Path()
        ..moveTo(rect.left + w * 0.28, y)
        ..lineTo(rect.left + w * 0.44, y + h * 0.14)
        ..lineTo(rect.left + w * 0.74, y - h * 0.16);
      canvas.drawPath(p, i == 2 ? ink : checkPaint);
      canvas.drawLine(Offset(rect.left + w * 0.92, y + h * 0.02), Offset(rect.right - w * 0.16, y + h * 0.02),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.02
            ..strokeCap = StrokeCap.round
            ..color = AppTheme.borderLight);
    }
    _sparkles(canvas, s, c, ink);
  }

  void _magnifier(Canvas canvas, Offset c, double s, Paint ink, Paint fill) {
    final lens = Offset(c.dx - s * 0.06, c.dy - s * 0.04);
    final r = s * 0.20;
    canvas.drawCircle(lens, r, fill..color = AppTheme.googleSky.withOpacity(0.5));
    canvas.drawCircle(lens, r, ink);
    // Handle
    final handle = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.055
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.royalNavy;
    canvas.drawLine(lens + Offset(r * 0.72, r * 0.72), lens + Offset(r * 1.55, r * 1.55), handle);
    // Glint
    final glint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.028
      ..strokeCap = StrokeCap.round
      ..color = Colors.white;
    canvas.drawArc(
      Rect.fromCircle(center: lens, radius: r * 0.62),
      math.pi * 1.05,
      math.pi * 0.35,
      false,
      glint,
    );
    // Question mark doodle
    final q = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.googleBlue;
    final qp = Path()
      ..moveTo(lens.dx - r * 0.25, lens.dy - r * 0.22)
      ..quadraticBezierTo(lens.dx, lens.dy - r * 0.75, lens.dx + r * 0.28, lens.dy - r * 0.28)
      ..quadraticBezierTo(lens.dx + r * 0.3, lens.dy + r * 0.05, lens.dx, lens.dy + r * 0.1);
    canvas.drawPath(qp, q);
    canvas.drawCircle(lens + Offset(0, r * 0.42), s * 0.016, fill..color = AppTheme.googleBlue);
    _sparkles(canvas, s, c, ink);
  }

  void _calendar(Canvas canvas, Offset c, double s, Paint ink, Paint fill) {
    final w = s * 0.30;
    final h = s * 0.26;
    final rect = Rect.fromCenter(center: c + Offset(0, s * 0.03), width: w * 2, height: h * 2);
    final rr = RRect.fromRectAndRadius(rect, Radius.circular(s * 0.05));
    canvas.drawRRect(rr, fill..color = Colors.white);
    canvas.drawRRect(rr, ink);
    // Header band
    final head = RRect.fromRectAndRadius(
      Rect.fromLTRB(rect.left, rect.top, rect.right, rect.top + h * 0.62),
      Radius.circular(s * 0.05),
    );
    canvas.save();
    canvas.clipRRect(head);
    canvas.drawRect(Rect.fromLTRB(rect.left, rect.top, rect.right, rect.top + h * 0.62), fill..color = AppTheme.googleBlush.withOpacity(0.8));
    canvas.drawLine(Offset(rect.left, rect.top + h * 0.62), Offset(rect.right, rect.top + h * 0.62), ink);
    canvas.restore();
    // Rings
    for (final x in [-w * 0.5, w * 0.5]) {
      canvas.drawLine(Offset(c.dx + x, rect.top - s * 0.045), Offset(c.dx + x, rect.top + s * 0.03),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.035
            ..strokeCap = StrokeCap.round
            ..color = AppTheme.googleRed);
    }
    // Dots grid
    for (int i = 0; i < 2; i++) {
      for (int j = 0; j < 4; j++) {
        canvas.drawCircle(
          Offset(rect.left + w * 0.35 + j * w * 0.44, rect.top + h * 1.05 + i * h * 0.55),
          s * 0.018,
          fill..color = i == 1 && j == 2 ? AppTheme.googleGreen : AppTheme.borderLight,
        );
      }
    }
    _sparkles(canvas, s, c, ink);
  }

  void _wifiOff(Canvas canvas, Offset c, double s, Paint ink, Paint fill) {
    final base = c + Offset(0, s * 0.16);
    // Arcs
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.035
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.textMuted;
    canvas.drawArc(Rect.fromCenter(center: base, width: s * 0.5, height: s * 0.5), math.pi * 1.2, math.pi * 0.6, false, arc);
    canvas.drawArc(Rect.fromCenter(center: base, width: s * 0.85, height: s * 0.85), math.pi * 1.25, math.pi * 0.5, false, arc);
    canvas.drawArc(Rect.fromCenter(center: base, width: s * 1.2, height: s * 1.2), math.pi * 1.3, math.pi * 0.4, false, arc);
    canvas.drawCircle(base, s * 0.035, fill..color = AppTheme.crimsonRose);
    // Slash
    final slash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.05
      ..strokeCap = StrokeCap.round
      ..color = AppTheme.crimsonRose;
    canvas.drawLine(c + Offset(-s * 0.3, -s * 0.3), c + Offset(s * 0.3, s * 0.3), slash);
    // Cloud doodle
    final cloud = Path()
      ..moveTo(c.dx - s * 0.16, c.dy - s * 0.22)
      ..quadraticBezierTo(c.dx - s * 0.20, c.dy - s * 0.34, c.dx - s * 0.08, c.dy - s * 0.34)
      ..quadraticBezierTo(c.dx - s * 0.02, c.dy - s * 0.44, c.dx + s * 0.08, c.dy - s * 0.36)
      ..quadraticBezierTo(c.dx + s * 0.20, c.dy - s * 0.38, c.dx + s * 0.18, c.dy - s * 0.26)
      ..quadraticBezierTo(c.dx + s * 0.24, c.dy - s * 0.16, c.dx + s * 0.10, c.dy - s * 0.20)
      ..quadraticBezierTo(c.dx - s * 0.06, c.dy - s * 0.12, c.dx - s * 0.16, c.dy - s * 0.22);
    canvas.drawPath(cloud, fill..color = AppTheme.googleLemon.withOpacity(0.9));
    canvas.drawPath(cloud, ink);
  }

  void _rocket(Canvas canvas, Offset c, double s, Paint ink, Paint fill) {
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(-0.35);
    // Body
    final body = Path()
      ..moveTo(0, -s * 0.30)
      ..quadraticBezierTo(s * 0.14, -s * 0.10, s * 0.10, s * 0.14)
      ..lineTo(-s * 0.10, s * 0.14)
      ..quadraticBezierTo(-s * 0.14, -s * 0.10, 0, -s * 0.30)
      ..close();
    canvas.drawPath(body, fill..color = Colors.white);
    canvas.drawPath(body, ink);
    // Window
    canvas.drawCircle(Offset(0, -s * 0.08), s * 0.05, fill..color = AppTheme.googleSky);
    canvas.drawCircle(Offset(0, -s * 0.08), s * 0.05, ink);
    // Fins
    final fin = Paint()
      ..style = PaintingStyle.fill
      ..color = AppTheme.googleRed.withOpacity(0.9);
    final finL = Path()
      ..moveTo(-s * 0.09, s * 0.02)
      ..lineTo(-s * 0.20, s * 0.16)
      ..lineTo(-s * 0.09, s * 0.14)
      ..close();
    final finR = Path()
      ..moveTo(s * 0.09, s * 0.02)
      ..lineTo(s * 0.20, s * 0.16)
      ..lineTo(s * 0.09, s * 0.14)
      ..close();
    canvas.drawPath(finL, fin);
    canvas.drawPath(finR, fin);
    canvas.drawPath(finL, ink);
    canvas.drawPath(finR, ink);
    // Flame
    final flame = Path()
      ..moveTo(-s * 0.05, s * 0.15)
      ..quadraticBezierTo(0, s * 0.38, s * 0.05, s * 0.15)
      ..close();
    canvas.drawPath(flame, fill..color = AppTheme.googleYellow.withOpacity(0.95));
    canvas.restore();
    // Motion puffs
    for (final o in [Offset(-s * 0.30, s * 0.30), Offset(-s * 0.40, s * 0.38), Offset(-s * 0.48, s * 0.48)]) {
      canvas.drawCircle(c + o, s * 0.022, fill..color = AppTheme.textMuted.withOpacity(0.5));
    }
    _sparkles(canvas, s, c, ink);
  }

  void _shield(Canvas canvas, Offset c, double s, Paint ink, Paint fill) {
    final path = Path()
      ..moveTo(c.dx, c.dy - s * 0.28)
      ..quadraticBezierTo(c.dx + s * 0.20, c.dy - s * 0.20, c.dx + s * 0.22, c.dy - s * 0.18)
      ..lineTo(c.dx + s * 0.20, c.dy + s * 0.06)
      ..quadraticBezierTo(c.dx + s * 0.16, c.dy + s * 0.24, c.dx, c.dy + s * 0.32)
      ..quadraticBezierTo(c.dx - s * 0.16, c.dy + s * 0.24, c.dx - s * 0.20, c.dy + s * 0.06)
      ..lineTo(c.dx - s * 0.22, c.dy - s * 0.18)
      ..quadraticBezierTo(c.dx - s * 0.20, c.dy - s * 0.20, c.dx, c.dy - s * 0.28)
      ..close();
    canvas.drawPath(path, fill..color = AppTheme.googleMint.withOpacity(0.85));
    canvas.drawPath(path, ink);
    final check = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.045
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = AppTheme.googleGreen;
    final p = Path()
      ..moveTo(c.dx - s * 0.09, c.dy)
      ..lineTo(c.dx - s * 0.02, c.dy + s * 0.08)
      ..lineTo(c.dx + s * 0.12, c.dy - s * 0.08);
    canvas.drawPath(p, check);
    _sparkles(canvas, s, c, ink);
  }

  @override
  bool shouldRepaint(_DoodleScenePainter oldDelegate) => oldDelegate.scene != scene;
}

/// Hand-drawn marker underline used beneath section headings.
class DoodleUnderline extends StatelessWidget {
  final Color color;
  final double width;
  final double height;

  const DoodleUnderline({
    super.key,
    this.color = AppTheme.googleYellow,
    this.width = 64,
    this.height = 8,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(painter: _UnderlinePainter(color: color)),
    );
  }
}

class _UnderlinePainter extends CustomPainter {
  final Color color;
  _UnderlinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.height * 0.42
      ..strokeCap = StrokeCap.round
      ..color = color.withOpacity(0.85);
    final p = Path()
      ..moveTo(size.width * 0.02, size.height * 0.55)
      ..quadraticBezierTo(size.width * 0.35, size.height * 0.15, size.width * 0.62, size.height * 0.6)
      ..quadraticBezierTo(size.width * 0.85, size.height * 0.95, size.width * 0.98, size.height * 0.5);
    canvas.drawPath(p, paint);
  }

  @override
  bool shouldRepaint(_UnderlinePainter oldDelegate) => oldDelegate.color != color;
}

/// Confetti burst used behind success moments (created, verified, exported…).
class DoodleConfetti extends StatelessWidget {
  final Animation<double> progress;
  final int particles;

  const DoodleConfetti({super.key, required this.progress, this.particles = 26});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) => CustomPaint(
        painter: _ConfettiPainter(progress: progress.value, particles: particles),
        size: Size.infinite,
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  final double progress;
  final int particles;
  _ConfettiPainter({required this.progress, required this.particles});

  static const List<Color> _palette = [
    AppTheme.googleRed,
    AppTheme.googleYellow,
    AppTheme.googleGreen,
    AppTheme.googleBlue,
    AppTheme.googlePurple,
    AppTheme.electricTeal,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(42);
    final center = Offset(size.width / 2, size.height * 0.32);
    for (int i = 0; i < particles; i++) {
      final angle = rng.nextDouble() * math.pi * 2;
      final speed = 0.45 + rng.nextDouble() * 0.75;
      final dist = progress * speed * size.width * 0.55;
      final pos = center + Offset(math.cos(angle) * dist, math.sin(angle) * dist * 0.8 + dist * 0.35);
      final color = _palette[i % _palette.length];
      final alpha = (1.0 - progress).clamp(0.0, 1.0);
      final paint = Paint()..color = color.withOpacity(alpha);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(angle * 2 + progress * 6);
      final kind = i % 3;
      if (kind == 0) {
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: 7, height: 4), paint);
      } else if (kind == 1) {
        canvas.drawCircle(Offset.zero, 2.6, paint);
      } else {
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: 3, height: 8), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Twinkling sparkle accent that can be sprinkled near headers/hero elements.
class DoodleSparkle extends StatefulWidget {
  final double size;
  final Color color;
  final Duration period;

  const DoodleSparkle({
    super.key,
    this.size = 20,
    this.color = AppTheme.googleYellow,
    this.period = const Duration(milliseconds: 1800),
  });

  @override
  State<DoodleSparkle> createState() => _DoodleSparkleState();
}

class _DoodleSparkleState extends State<DoodleSparkle> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period)..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Transform.scale(
          scale: 0.7 + 0.3 * t,
          child: Opacity(
            opacity: 0.45 + 0.55 * t,
            child: SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _SparklePainter(color: widget.color),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SparklePainter extends CustomPainter {
  final Color color;
  _SparklePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx + r * 0.16, c.dy - r * 0.16, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx + r * 0.16, c.dy + r * 0.16, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx - r * 0.16, c.dy + r * 0.16, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx - r * 0.16, c.dy - r * 0.16, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_SparklePainter oldDelegate) => oldDelegate.color != color;
}

/// Wavy bottom edge used under doodle hero headers.
class DoodleWaveEdge extends StatelessWidget {
  final Color color;
  final double height;

  const DoodleWaveEdge({super.key, required this.color, this.height = 26});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: _WavePainter(color: color)),
    );
  }
}

class _WavePainter extends CustomPainter {
  final Color color;
  _WavePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.fill
      ..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(size.width * 0.125, size.height, size.width * 0.25, size.height * 0.45)
      ..quadraticBezierTo(size.width * 0.375, 0, size.width * 0.5, size.height * 0.42)
      ..quadraticBezierTo(size.width * 0.625, size.height * 0.85, size.width * 0.75, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.875, 0, size.width, size.height * 0.35)
      ..lineTo(size.width, 0)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter oldDelegate) => oldDelegate.color != color;
}
