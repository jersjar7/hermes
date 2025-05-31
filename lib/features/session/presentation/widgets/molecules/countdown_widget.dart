// lib/features/session/presentation/widgets/molecules/countdown_widget.dart

import 'package:flutter/material.dart';
import '../atoms/countdown_number.dart';

/// A circular countdown display with progress ring and number.
/// Shows time remaining before session playback begins.
class CountdownWidget extends StatelessWidget {
  final int seconds;
  final int totalSeconds;
  final double size;

  const CountdownWidget({
    super.key,
    required this.seconds,
    this.totalSeconds = 8,
    this.size = 120.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = seconds > 0 ? seconds / totalSeconds : 0.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background circle
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: theme.colorScheme.surface,
              border: Border.all(
                color: theme.colorScheme.outline.withValues(alpha: 0.2),
                width: 2,
              ),
            ),
          ),

          // Progress ring
          SizedBox(
            width: size - 8,
            height: size - 8,
            child: AnimatedBuilder(
              animation: AlwaysStoppedAnimation(progress),
              builder: (context, child) {
                return CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 4,
                  backgroundColor: Colors.transparent,
                  valueColor: AlwaysStoppedAnimation(_getProgressColor(theme)),
                );
              },
            ),
          ),

          // Countdown number
          CountdownNumber(seconds: seconds, size: size * 0.3),
        ],
      ),
    );
  }

  Color _getProgressColor(ThemeData theme) {
    if (seconds <= 3) return theme.colorScheme.error;
    if (seconds <= 5) return Colors.amber;
    return theme.colorScheme.primary;
  }
}
