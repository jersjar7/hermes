// lib/features/session/presentation/widgets/molecules/transcript_header.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/widgets/animations/pulse_animation.dart';
import '../atoms/live_indicator.dart';
import '../../utils/transcript_message.dart';

/// Header for the transcript chat box showing title, status, and indicators
class TranscriptHeader extends StatelessWidget {
  final HermesStatus status;
  final bool hasEverSpoken;
  final int messageCount;

  const TranscriptHeader({
    super.key,
    required this.status,
    required this.hasEverSpoken,
    this.messageCount = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isListening = status == HermesStatus.listening;
    final isTranslating = status == HermesStatus.translating;
    final hasActivity = isListening || isTranslating || messageCount > 0;

    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        color:
            hasActivity
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.1)
                : null,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(HermesSpacing.md),
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Dynamic icon with subtle animation
          PulseAnimation(
            animate: isListening,
            minScale: 0.95,
            maxScale: 1.05,
            child: Icon(
              TranscriptUtils.getHeaderIcon(status),
              size: 20,
              color:
                  hasActivity
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: HermesSpacing.sm),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  TranscriptUtils.getHeaderTitle(status, hasEverSpoken),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color:
                        hasActivity
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  TranscriptUtils.getHeaderSubtitle(status, hasEverSpoken),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),

          // Status indicator
          _buildStatusIndicator(context, theme),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, ThemeData theme) {
    final isListening = status == HermesStatus.listening;

    if (messageCount > 0) {
      // Show message count
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HermesSpacing.sm,
          vertical: HermesSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '$messageCount',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (isListening) {
      // Show live indicator
      return const LiveIndicator(isLive: true);
    }

    return const SizedBox.shrink();
  }
}
