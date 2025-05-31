// lib/features/session/presentation/widgets/atoms/countdown_number.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/durations.dart';

/// Displays a countdown number with smooth transitions and color changes.
/// Used in countdown timers before session playback begins.
class CountdownNumber extends StatelessWidget {
  final int seconds;
  final double size;
  final FontWeight fontWeight;

  const CountdownNumber({
    super.key,
    required this.seconds,
    this.size = 48.0,
    this.fontWeight = FontWeight.bold,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedSwitcher(
      duration: HermesDurations.fast,
      transitionBuilder: (child, animation) {
        return ScaleTransition(
          scale: animation,
          child: FadeTransition(opacity: animation, child: child),
        );
      },
      child: Text(
        seconds.toString(),
        key: ValueKey(seconds),
        style: TextStyle(
          fontSize: size,
          fontWeight: fontWeight,
          color: _getNumberColor(theme),
        ),
      ),
    );
  }

  Color _getNumberColor(ThemeData theme) {
    if (seconds <= 3) return theme.colorScheme.error;
    if (seconds <= 5) return Colors.amber;
    return theme.colorScheme.primary;
  }
}
