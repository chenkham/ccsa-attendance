import 'dart:async';

import 'package:flutter/material.dart';

/// Auto-scrolling text for tight spaces.
/// If the text fits, it renders statically. If it overflows, it smoothly
/// scrolls left↔right in a continuous loop so the user can read everything —
/// no permanent "..." truncation.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration scrollPause;
  final bool enableFade;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.scrollPause = const Duration(milliseconds: 700),
    this.enableFade = true,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late final ScrollController _scrollController;
  Timer? _pauseTimer;
  bool _isScrollingForward = true;
  bool _needsScroll = false;
  int _layoutRetries = 0;
  double _lastWidth = -1;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text || oldWidget.style != widget.style) {
      _pauseTimer?.cancel();
      _isScrollingForward = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    }
  }

  /// Measures whether the text overflows. Retries across frames because the
  /// scroll controller only attaches after layout — without the retry the
  /// marquee could silently never start (the original "stuck clipped" bug).
  void _measure() {
    if (!mounted) return;
    if (!_scrollController.hasClients) {
      if (_layoutRetries++ < 60) {
        WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
      }
      return;
    }
    _layoutRetries = 0;

    final max = _scrollController.position.maxScrollExtent;
    final needs = max > 2.0;

    if (needs != _needsScroll) {
      setState(() => _needsScroll = needs);
    }
    if (needs) {
      if (_scrollController.offset > max) _scrollController.jumpTo(0);
      _scheduleNextLeg();
    } else {
      _pauseTimer?.cancel();
      _isScrollingForward = true;
    }
  }

  void _scheduleNextLeg() {
    _pauseTimer?.cancel();
    _pauseTimer = Timer(widget.scrollPause, () async {
      if (!mounted || !_scrollController.hasClients) return;
      final max = _scrollController.position.maxScrollExtent;
      if (max <= 0) return;

      final target = _isScrollingForward ? max : 0.0;
      final distance = (target - _scrollController.offset).abs();
      if (distance <= 0.5) {
        _isScrollingForward = !_isScrollingForward;
        _scheduleNextLeg();
        return;
      }

      // ~45 px per second, clamped so long titles stay readable
      final duration = Duration(milliseconds: (distance / 0.045).clamp(900, 6000).toInt());
      try {
        await _scrollController.animateTo(target, duration: duration, curve: Curves.easeInOut);
      } catch (_) {}

      if (!mounted) return;
      _isScrollingForward = !_isScrollingForward;
      _scheduleNextLeg();
    });
  }

  @override
  void dispose() {
    _pauseTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Re-measure when the available width changes (rotate / window resize)
        if ((constraints.maxWidth - _lastWidth).abs() > 1) {
          _lastWidth = constraints.maxWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
        }

        final content = SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Text(
            widget.text,
            style: widget.style,
            textAlign: widget.textAlign,
            maxLines: 1,
            softWrap: false,
          ),
        );

        if (!_needsScroll || !widget.enableFade) return content;

        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.04, 0.96, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: content,
        );
      },
    );
  }
}
