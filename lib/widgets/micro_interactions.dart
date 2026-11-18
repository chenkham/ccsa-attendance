import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// ============================================================================
/// CCSA Expressive — Micro-Interaction Library
/// Springy press feedback, staggered entrances, animated data, live pulses.
/// All widgets are pure presentation: they never alter business logic.
/// ============================================================================

/// Spring press feedback: scales down while pressed and springs back on
/// release (Material 3 Expressive "squish"). Wrap any tappable child.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double pressedScale;
  final BorderRadius? borderRadius;
  final MouseCursor cursor;

  const PressableScale({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.pressedScale = 0.965,
    this.borderRadius,
    this.cursor = SystemMouseCursors.click,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: AppTheme.motionFast);
    _scale = Tween<double>(begin: 1.0, end: widget.pressedScale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: widget.cursor,
      child: GestureDetector(
        onTapDown: widget.onTap != null || widget.onLongPress != null
            ? (_) {
                _controller.forward();
                AppTheme.triggerSelectionHaptic();
              }
            : null,
        onTapCancel: () => _controller.reverse(),
        onTap: widget.onTap == null
            ? null
            : () {
                _controller.reverse();
                widget.onTap!();
              },
        onLongPress: widget.onLongPress,
        child: AnimatedBuilder(
          animation: _scale,
          builder: (context, child) => Transform.scale(
            scale: _scale.value,
            child: child,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Number that animates (counts) from its previous value to the new one.
class AnimatedCounter extends StatefulWidget {
  final num value;
  final TextStyle style;
  final Duration duration;
  final String? suffix;

  const AnimatedCounter({
    super.key,
    required this.value,
    required this.style,
    this.duration = const Duration(milliseconds: 700),
    this.suffix,
  });

  @override
  State<AnimatedCounter> createState() => _AnimatedCounterState();
}

class _AnimatedCounterState extends State<AnimatedCounter> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _anim;
  num _from = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    // CRITICAL: tween to the FIRST value immediately — otherwise the counter
    // stays at 0 forever until the value changes between rebuilds.
    _anim = Tween<double>(begin: 0, end: widget.value.toDouble()).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCounter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _from = _anim.value;
      _anim = Tween<double>(begin: _from.toDouble(), end: widget.value.toDouble()).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
      );
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _format(double v) {
    if (widget.value is int || widget.value.runtimeType == int) {
      return v.round().toString();
    }
    return v.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        return Text(
          '${_format(_anim.value)}${widget.suffix ?? ''}',
          key: ValueKey(widget.value),
          style: widget.style,
        );
      },
    );
  }
}

/// Fade + slide entrance for list children. Wrap each item with an index to
/// get a gentle cascade. Skips animation when `animate` is false (rebuilds).
class StaggeredEntrance extends StatefulWidget {
  final Widget child;
  final int index;
  final Duration baseDelay;
  final double slideDistance;

  const StaggeredEntrance({
    super.key,
    required this.child,
    this.index = 0,
    this.baseDelay = const Duration(milliseconds: 45),
    this.slideDistance = 18,
  });

  @override
  State<StaggeredEntrance> createState() => _StaggeredEntranceState();
}

class _StaggeredEntranceState extends State<StaggeredEntrance> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    // Timer-free stagger: fold the per-index delay into the controller
    // duration and gate visibility with an Interval curve instead of
    // Future.delayed (keeps widget tests free of pending timers).
    final int clampedIndex = widget.index.clamp(0, 10);
    final int delayMs = widget.baseDelay.inMilliseconds * clampedIndex;
    final int animMs = AppTheme.motionSlow.inMilliseconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: delayMs + animMs),
    );
    final double start = delayMs == 0 ? 0.0 : delayMs / (delayMs + animMs);
    _fade = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1.0, curve: Curves.easeOut),
    );
    _slide = Tween<double>(begin: widget.slideDistance, end: 0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Interval(start, 1.0, curve: AppTheme.curveExpressive),
      ),
    );
    _controller.forward();
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
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Linear progress that animates from zero to `value` whenever shown.
class AnimatedProgressBar extends StatefulWidget {
  final double value; // 0..1
  final double height;
  final Color color;
  final Color trackColor;
  final Duration duration;

  const AnimatedProgressBar({
    super.key,
    required this.value,
    this.height = 8,
    this.color = AppTheme.emeraldGreen,
    this.trackColor = AppTheme.borderLight,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<AnimatedProgressBar> createState() => _AnimatedProgressBarState();
}

class _AnimatedProgressBarState extends State<AnimatedProgressBar> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _curve;

  @override
  void initState() {
    super.initState();
    // Timer-free lead-in: a short interval beat instead of Future.delayed.
    const int leadMs = 120;
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration + const Duration(milliseconds: leadMs),
    );
    final double start = leadMs / _controller.duration!.inMilliseconds;
    _curve = CurvedAnimation(
      parent: _controller,
      curve: Interval(start, 1.0, curve: Curves.easeOutCubic),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      builder: (context, _) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(widget.height),
          child: SizedBox(
            height: widget.height,
            child: Stack(
              children: [
                Container(color: widget.trackColor),
                FractionallySizedBox(
                  widthFactor: (widget.value * _curve.value).clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [widget.color, widget.color.withOpacity(0.75)],
                      ),
                      borderRadius: BorderRadius.circular(widget.height),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Breathing glow pulse for live elements (active QR, recording dots…).
class PulseGlow extends StatefulWidget {
  final Widget child;
  final Color glowColor;
  final double minRadius;
  final double maxRadius;
  final Duration period;

  const PulseGlow({
    super.key,
    required this.child,
    required this.glowColor,
    this.minRadius = 6,
    this.maxRadius = 18,
    this.period = const Duration(milliseconds: 1600),
  });

  @override
  State<PulseGlow> createState() => _PulseGlowState();
}

class _PulseGlowState extends State<PulseGlow> with SingleTickerProviderStateMixin {
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
        return DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.glowColor.withOpacity(0.30 * (1 - t)),
                blurRadius: widget.minRadius + (widget.maxRadius - widget.minRadius) * (1 - t),
                spreadRadius: 1,
              ),
            ],
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}

/// Shimmer skeleton placeholder for loading states.
class ShimmerSkeleton extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius radius;

  const ShimmerSkeleton({
    super.key,
    this.width = double.infinity,
    required this.height,
    this.radius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<ShimmerSkeleton> createState() => _ShimmerSkeletonState();
}

class _ShimmerSkeletonState extends State<ShimmerSkeleton> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat();
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
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.radius,
            gradient: LinearGradient(
              begin: Alignment(-1.0 - 2 * t + t, 0),
              end: Alignment(1.0 + 2 * (1 - t), 0),
              colors: const [
                Color(0xFFEDF1F7),
                Color(0xFFF8FAFD),
                Color(0xFFEDF1F7),
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
          ),
        );
      },
    );
  }
}

/// Branded loading state with orbiting dots (used instead of bare spinners).
class BrandLoader extends StatefulWidget {
  final String? message;
  final double size;
  final Color color;

  const BrandLoader({super.key, this.message, this.size = 44, this.color = AppTheme.royalNavy});

  @override
  State<BrandLoader> createState() => _BrandLoaderState();
}

class _BrandLoaderState extends State<BrandLoader> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: widget.size,
          height: widget.size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              return CustomPaint(
                painter: _OrbitDotsPainter(
                  progress: _controller.value,
                  color: widget.color,
                ),
              );
            },
          ),
        ),
        if (widget.message != null) ...[
          const SizedBox(height: 14),
          Text(
            widget.message!,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ],
    );
  }
}

class _OrbitDotsPainter extends CustomPainter {
  final double progress;
  final Color color;
  _OrbitDotsPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width * 0.34;
    for (int i = 0; i < 3; i++) {
      final phase = (progress + i / 3) % 1.0;
      final angle = phase * 2 * math.pi;
      final pos = c + Offset(math.cos(angle) * r, math.sin(angle) * r);
      final alpha = 0.35 + 0.65 * (1 - phase);
      canvas.drawCircle(pos, size.width * 0.075 * (0.7 + 0.5 * (1 - phase)), Paint()..color = color.withOpacity(alpha));
    }
    // Center dot
    canvas.drawCircle(c, size.width * 0.055, Paint()..color = color.withOpacity(0.9));
  }

  @override
  bool shouldRepaint(_OrbitDotsPainter oldDelegate) => oldDelegate.progress != progress;
}

/// Draws a checkmark stroke progressively — success feedback moment.
class AnimatedSuccessCheck extends StatefulWidget {
  final double size;
  final Color color;
  final VoidCallback? onDone;

  const AnimatedSuccessCheck({super.key, this.size = 64, this.color = AppTheme.googleGreen, this.onDone});

  @override
  State<AnimatedSuccessCheck> createState() => _AnimatedSuccessCheckState();
}

class _AnimatedSuccessCheckState extends State<AnimatedSuccessCheck> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _controller.forward().then((_) => widget.onDone?.call());
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
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _CheckPainter(progress: t, color: widget.color),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    final r = size.width / 2;
    // Expanding circle
    final circleAlpha = (progress * 1.4).clamp(0.0, 1.0);
    canvas.drawCircle(c, r * (0.6 + 0.4 * circleAlpha), Paint()..color = color.withOpacity(0.16 * circleAlpha));
    canvas.drawCircle(c, r * 0.82, Paint()..color = color.withOpacity(0.9 * circleAlpha));
    // Check stroke
    final checkPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.09
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = Colors.white;
    final path = Path()
      ..moveTo(c.dx - r * 0.34, c.dy + r * 0.02)
      ..lineTo(c.dx - r * 0.08, c.dy + r * 0.28)
      ..lineTo(c.dx + r * 0.38, c.dy - r * 0.24);
    final metric = path.computeMetrics().first;
    canvas.drawPath(metric.extractPath(0, metric.length * progress.clamp(0.0, 1.0)), checkPaint);
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) => oldDelegate.progress != progress;
}
