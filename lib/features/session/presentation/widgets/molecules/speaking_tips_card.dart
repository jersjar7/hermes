// lib/features/session/presentation/widgets/molecules/speaking_tips_card.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';

/// Card displaying helpful speaking tips for first-time users
class SpeakingTipsCard extends StatelessWidget {
  const SpeakingTipsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(HermesSpacing.sm),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: HermesSpacing.xs),
              Text(
                'Speaking Tips',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: HermesSpacing.sm),
          ...[
            'Speak clearly at a normal pace',
            'Pause briefly between sentences',
            'Keep device 6-12 inches away',
          ].map((tip) => _buildTip(tip, theme)),
        ],
      ),
    );
  }

  Widget _buildTip(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: HermesSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 3,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: HermesSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
