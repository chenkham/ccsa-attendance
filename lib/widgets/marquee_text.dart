import 'dart:async';
import 'package:flutter/material.dart';

/// A sleek, self-animating horizontal ticker text widget.
/// When the text is longer than the available constraint width,
/// it smoothly auto-scrolls from left to right and loops back so users can read the entire text.
class MarqueeText extends StatefulWidget {
  final String text;
  final TextStyle? style;
  final TextAlign textAlign;
  final Duration scrollDuration;
  final Duration pauseDuration;

  const MarqueeText({
    super.key,
    required this.text,
    this.style,
    this.textAlign = TextAlign.start,
    this.scrollDuration = const Duration(seconds: 4),
    this.pauseDuration = const Duration(milliseconds: 1400),
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText> {
  late final ScrollController _scrollController;
  Timer? _timer;
  bool _isScrollingForward = true;
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
  }

  @override
  void didUpdateWidget(MarqueeText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) {
      _stopAnimation();
      WidgetsBinding.instance.addPostFrameCallback((_) => _startAnimation());
    }
  }

  void _startAnimation() {
    if (!mounted || !_scrollController.hasClients) return;

    final maxScroll = _scrollController.position.maxScrollExtent;
    if (maxScroll <= 0) {
      if (_needsScroll) setState(() => _needsScroll = false);
      return;
    }

    if (!_needsScroll) {
      setState(() => _needsScroll = true);
    }

    _scheduleScroll();
  }

  void _scheduleScroll() {
    _timer?.cancel();
    if (!mounted || !_scrollController.hasClients) return;

    _timer = Timer(widget.pauseDuration, () async {
      if (!mounted || !_scrollController.hasClients) return;
      final maxScroll = _scrollController.position.maxScrollExtent;
      if (maxScroll <= 0) return;

      final target = _isScrollingForward ? maxScroll : 0.0;
      final distance = (target - _scrollController.offset).abs();
      if (distance <= 0) {
        _isScrollingForward = !_isScrollingForward;
        _scheduleScroll();
        return;
      }

      // Calculate dynamic duration based on text distance
      final duration = Duration(milliseconds: (distance * 38).clamp(1200, 8000).toInt());

      try {
        await _scrollController.animateTo(
          target,
          duration: duration,
          curve: Curves.easeInOutCubic,
        );
      } catch (_) {}

      if (!mounted) return;
      _isScrollingForward = !_isScrollingForward;
      _scheduleScroll();
    });
  }

  void _stopAnimation() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  void dispose() {
    _stopAnimation();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final content = SingleChildScrollView(
          controller: _scrollController,
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          child: Text(
            widget.text,
            style: widget.style,
            textAlign: widget.textAlign,
            maxLines: 1,
          ),
        );

        if (!_needsScroll) return content;

        return ShaderMask(
          shaderCallback: (Rect bounds) {
            return const LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.white,
                Colors.white,
                Colors.white,
                Colors.transparent,
              ],
              stops: [0.0, 0.05, 0.92, 1.0],
            ).createShader(bounds);
          },
          blendMode: BlendMode.dstIn,
          child: content,
        );
      },
    );
  }
}
