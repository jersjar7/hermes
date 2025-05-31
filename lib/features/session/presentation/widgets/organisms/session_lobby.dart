// lib/features/session/presentation/widgets/organisms/session_lobby.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/core/presentation/widgets/buttons/primary_button.dart';
import 'package:hermes/core/presentation/widgets/cards/glass_card.dart';
import 'package:hermes/features/session/presentation/utils/language_helpers.dart';
import '../molecules/session_code_display.dart';
import '../atoms/language_flag.dart';

/// Session lobby showing session code and go live controls.
/// Intermediate step between language selection and active session.
class SessionLobby extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
