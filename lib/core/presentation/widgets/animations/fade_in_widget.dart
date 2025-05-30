// lib/core/presentation/widgets/animations/fade_in_widget.dart

import 'package:flutter/material.dart';
import '../../constants/durations.dart';

/// Fades in a widget when it first appears.
/// Optionally slides from a direction.
class FadeInWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset slideFrom;

  const FadeInWidget({
    super.key,
    required this.child,
    this.duration = HermesDurations.normal,
    this.delay = Duration.zero,
    this.slideFrom = Offset.zero,
  });

  @override
  State<FadeInWidget> createState() => _FadeInWidgetState();
}

class _FadeInWidgetState extends State<FadeInWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<Offset> _position;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: HermesDurations.enterCurve),
    );

    _position = Tween<Offset>(
      begin: widget.slideFrom,
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: HermesDurations.enterCurve),
    );

    Future.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _position, child: widget.child),
    );
  }
}
