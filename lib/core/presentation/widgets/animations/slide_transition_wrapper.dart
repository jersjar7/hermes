// lib/core/presentation/widgets/animations/slide_transition_wrapper.dart

import 'package:flutter/material.dart';
import '../../constants/durations.dart';

/// Wraps a widget to slide in/out based on visibility.
/// Perfect for showing/hiding UI elements smoothly.
class SlideTransitionWrapper extends StatelessWidget {
  final Widget child;
  final bool isVisible;
  final Duration duration;
  final SlideDirection direction;
  final Curve curve;

  const SlideTransitionWrapper({
    super.key,
    required this.child,
    required this.isVisible,
    this.duration = HermesDurations.fast,
    this.direction = SlideDirection.down,
    this.curve = Curves.easeInOut,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSlide(
      duration: duration,
      curve: curve,
      offset: isVisible ? Offset.zero : _getOffset(),
      child: AnimatedOpacity(
        duration: duration,
        curve: curve,
        opacity: isVisible ? 1.0 : 0.0,
        child: child,
      ),
    );
  }

  Offset _getOffset() {
    switch (direction) {
      case SlideDirection.up:
        return const Offset(0, -1);
      case SlideDirection.down:
        return const Offset(0, 1);
      case SlideDirection.left:
        return const Offset(-1, 0);
      case SlideDirection.right:
        return const Offset(1, 0);
    }
  }
}

/// Direction from which the widget slides.
enum SlideDirection { up, down, left, right }
