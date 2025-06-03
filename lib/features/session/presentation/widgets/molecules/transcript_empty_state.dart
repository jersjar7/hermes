// lib/features/session/presentation/widgets/molecules/transcript_empty_state.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'speaking_tips_card.dart';
import '../../utils/transcript_message.dart';

/// Empty state display for when no transcript messages exist
class TranscriptEmptyState extends StatelessWidget {
  final HermesStatus status;
  final bool hasEverSpoken;

  const TranscriptEmptyState({
    super.key,
    required this.status,
    required this.hasEverSpoken,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isReady =
        status == HermesStatus.listening || status == HermesStatus.buffering;
    final isListening = status == HermesStatus.listening;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Adapt content based on available height
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 300;

        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: availableHeight),
            child: Padding(
              padding: EdgeInsets.all(
                isCompact ? HermesSpacing.md : HermesSpacing.xl,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Elegant microphone icon - smaller when compact
                  Container(
                    width: isCompact ? 48 : 64,
                    height: isCompact ? 48 : 64,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primaryContainer.withValues(
                        alpha: 0.2,
                      ),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: theme.colorScheme.primary.withValues(alpha: 0.2),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      isListening
                          ? HermesIcons.listening
                          : HermesIcons.microphone,
                      size: isCompact ? 20 : 28,
                      color: theme.colorScheme.primary.withValues(alpha: 0.7),
                    ),
                  ),

                  SizedBox(
                    height: isCompact ? HermesSpacing.md : HermesSpacing.lg,
                  ),

                  Text(
                    TranscriptUtils.getEmptyStateTitle(status, hasEverSpoken),
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurface,
                      fontSize: isCompact ? 14 : null,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  SizedBox(
                    height: isCompact ? HermesSpacing.xs : HermesSpacing.sm,
                  ),

                  Text(
                    TranscriptUtils.getEmptyStateSubtitle(
                      status,
                      hasEverSpoken,
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                      height: 1.4,
                      fontSize: isCompact ? 12 : null,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  // Subtle speaking tips for new sessions - only show if enough space
                  if (!hasEverSpoken && isReady && !isCompact) ...[
                    const SizedBox(height: HermesSpacing.xl),
                    const SpeakingTipsCard(),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
