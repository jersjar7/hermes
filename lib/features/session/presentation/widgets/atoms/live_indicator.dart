// lib/features/session/presentation/widgets/atoms/live_indicator.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/widgets/animations/pulse_animation.dart';

/// Live recording indicator with pulsing animation
class LiveIndicator extends StatelessWidget {
  final bool isLive;
  final double size;

  const LiveIndicator({super.key, required this.isLive, this.size = 6.0});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!isLive) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HermesSpacing.sm,
        vertical: HermesSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulseAnimation(
            animate: true,
            child: Container(
              width: size,
              height: size,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            'LIVE',
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.greenAccent.shade700,
              fontWeight: FontWeight.w800,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}
