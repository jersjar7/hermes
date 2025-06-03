// lib/features/session/presentation/widgets/atoms/transcript_message_bubble.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import '../../utils/transcript_message.dart';

/// Individual message bubble displaying a transcript entry
class TranscriptMessageBubble extends StatelessWidget {
  final TranscriptMessage message;
  final bool isLatest;

  const TranscriptMessageBubble({
    super.key,
    required this.message,
    this.isLatest = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: HermesSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              HermesIcons.microphone,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(width: HermesSpacing.sm),

          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message bubble
                Container(
                  padding: const EdgeInsets.all(HermesSpacing.md),
                  decoration: BoxDecoration(
                    color:
                        isLatest
                            ? theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.2,
                            )
                            : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(HermesSpacing.md),
                      bottomLeft: Radius.circular(HermesSpacing.md),
                      bottomRight: Radius.circular(HermesSpacing.md),
                    ),
                    border:
                        isLatest
                            ? Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.2,
                              ),
                              width: 1,
                            )
                            : null,
                  ),
                  child: Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          isLatest
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                      fontWeight:
                          isLatest ? FontWeight.w500 : FontWeight.normal,
                      height: 1.4,
                    ),
                  ),
                ),

                const SizedBox(height: HermesSpacing.xs),

                // Timestamp
                Text(
                  TranscriptUtils.formatTimestamp(message.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
