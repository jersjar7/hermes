// lib/features/session/presentation/widgets/organisms/session_lobby.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/core/presentation/widgets/buttons/primary_button.dart';
import 'package:hermes/core/presentation/widgets/cards/glass_card.dart';
import 'package:hermes/features/session/presentation/utils/language_helpers.dart';
import '../molecules/session_code_display.dart';
import '../molecules/audience_info.dart';
import '../atoms/language_flag.dart';

/// Session lobby showing session code, audience info, and go live controls.
/// Enhanced with real-time audience tracking before going live.
class SessionLobby extends ConsumerWidget {
  final String sessionCode;
  final LanguageOption selectedLanguage;
  final VoidCallback onGoLive;

  const SessionLobby({
    super.key,
    required this.sessionCode,
    required this.selectedLanguage,
    required this.onGoLive,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessionState = ref.watch(hermesControllerProvider);

    return Padding(
      padding: const EdgeInsets.all(HermesSpacing.lg),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Session created success message
            GlassCard(
              child: Column(
                children: [
                  Icon(
                    Icons.check_circle_rounded,
                    size: 64,
                    color: Colors.green,
                  ),
                  const SizedBox(height: HermesSpacing.md),
                  Text(
                    'Session Created Successfully!',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.green,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: HermesSpacing.sm),
                  Text(
                    'Share the session code below with your audience',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: HermesSpacing.lg),

            // Session details card
            GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Selected language
                  Row(
                    children: [
                      LanguageFlag(flag: selectedLanguage.flag, size: 32),
                      const SizedBox(width: HermesSpacing.md),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Speaking Language',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.outline,
                            ),
                          ),
                          Text(
                            selectedLanguage.name,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: HermesSpacing.lg),

                  // Session code
                  Text('Session Code', style: theme.textTheme.labelLarge),
                  const SizedBox(height: HermesSpacing.sm),

                  Center(
                    child: Column(
                      children: [
                        SessionCodeDisplay(code: sessionCode),
                        const SizedBox(height: HermesSpacing.md),

                        // Copy button
                        TextButton.icon(
                          onPressed: () => _copySessionCode(context),
                          icon: const Icon(HermesIcons.copy, size: 16),
                          label: const Text('Copy Code'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: HermesSpacing.lg),

            // Audience information (real-time updates)
            sessionState.when(
              data: (state) => _buildAudienceSection(context, state),
              loading: () => _buildAudienceSkeleton(context),
              error: (_, __) => const SizedBox.shrink(),
            ),

            const SizedBox(height: HermesSpacing.lg),

            // Instructions
            Container(
              padding: const EdgeInsets.all(HermesSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(HermesSpacing.md),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(height: HermesSpacing.xs),
                  Text(
                    'Your audience can join this session using the code above. '
                    'When you\'re ready to start translating, tap "Go Live" below.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.primary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: HermesSpacing.lg),

            // Go Live button
            PrimaryButton(
              label: 'Go Live',
              icon: HermesIcons.speaker,
              isFullWidth: true,
              onPressed: onGoLive,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAudienceSection(BuildContext context, state) {
    final theme = Theme.of(context);
    final hasAudience = state.hasAudience;

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                HermesIcons.people,
                size: 20,
                color:
                    hasAudience
                        ? theme.colorScheme.primary
                        : theme.colorScheme.outline,
              ),
              const SizedBox(width: HermesSpacing.sm),
              Text(
                'Audience Status',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                      hasAudience
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outline,
                ),
              ),
            ],
          ),

          const SizedBox(height: HermesSpacing.md),

          if (hasAudience) ...[
            // Show audience info when people have joined
            AudienceInfo(
              totalListeners: state.audienceCount,
              languageDistribution: state.languageDistribution,
              showIcon: false,
              textStyle: theme.textTheme.bodyLarge,
            ),

            const SizedBox(height: HermesSpacing.sm),

            // Language breakdown if multiple languages
            if (state.uniqueLanguageCount > 1) ...[
              Text(
                'Language Breakdown:',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
              const SizedBox(height: HermesSpacing.xs),
              ...state.languageDistribution.entries.map((entry) {
                final percentage =
                    ((entry.value / state.audienceCount) * 100).round();
                return Padding(
                  padding: const EdgeInsets.only(bottom: HermesSpacing.xs),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(entry.key, style: theme.textTheme.bodyMedium),
                      Text(
                        '${entry.value} listeners ($percentage%)',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ],

            const SizedBox(height: HermesSpacing.sm),

            // Encouragement message
            Container(
              padding: const EdgeInsets.all(HermesSpacing.sm),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(HermesSpacing.sm),
              ),
              child: Row(
                children: [
                  Icon(Icons.thumb_up_rounded, size: 16, color: Colors.green),
                  const SizedBox(width: HermesSpacing.xs),
                  Expanded(
                    child: Text(
                      'Great! Your audience is ready to listen.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.green,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // Show waiting message when no audience yet
            Container(
              padding: const EdgeInsets.all(HermesSpacing.md),
              child: Column(
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    size: 32,
                    color: theme.colorScheme.outline,
                  ),
                  const SizedBox(height: HermesSpacing.sm),
                  Text(
                    'Waiting for audience to join...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                  const SizedBox(height: HermesSpacing.xs),
                  Text(
                    'Share the session code to get started',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAudienceSkeleton(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: HermesSpacing.sm),
              Container(
                width: 120,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
          const SizedBox(height: HermesSpacing.md),
          Container(
            width: double.infinity,
            height: 60,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }

  void _copySessionCode(BuildContext context) {
    Clipboard.setData(ClipboardData(text: sessionCode));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Session code copied to clipboard'),
        duration: Duration(seconds: 2),
      ),
    );
  }
}
