// lib/features/session/presentation/widgets/molecules/waveform_display.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import '../atoms/waveform_bar.dart';

/// Audio waveform visualization using multiple animated bars.
/// Shows speaking activity during speech-to-text input.
class WaveformDisplay extends StatelessWidget {
  final bool isActive;
  final int barCount;
  final double maxHeight;
  final Color? color;

  const WaveformDisplay({
    super.key,
    required this.isActive,
    this.barCount = 7,
    this.maxHeight = 40.0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final waveColor = color ?? theme.colorScheme.primary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (int i = 0; i < barCount; i++) ...[
          WaveformBar(
            maxHeight: _getBarHeight(i),
            color: isActive ? waveColor : waveColor.withValues(alpha: 0.3),
            isAnimating: isActive,
            animationDelay: Duration(milliseconds: i * 100),
          ),
          if (i < barCount - 1) const SizedBox(width: HermesSpacing.xs),
        ],
      ],
    );
  }

  double _getBarHeight(int index) {
    // Create varied heights for visual interest
    final middle = barCount ~/ 2;
    final distance = (index - middle).abs();
    final factor = 1.0 - (distance * 0.15);
    return maxHeight * factor.clamp(0.3, 1.0);
  }
}
