// lib/features/session/presentation/pages/audience_setup_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/presentation/widgets/cards/elevated_card.dart';
import 'package:hermes/features/app/presentation/widgets/hermes_app_bar.dart';
import 'package:hermes/features/session/presentation/utils/language_helpers.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import '../controllers/session_code_input_controller.dart';
import '../widgets/organisms/session_header.dart';
import '../widgets/organisms/session_join_form.dart';
import '../widgets/organisms/language_selector.dart';

/// Audience setup page for joining existing sessions.
/// Handles session code input and target language selection, then navigates to audience active page.
class AudienceSetupPage extends ConsumerStatefulWidget {
  const AudienceSetupPage({super.key});

  @override
  ConsumerState<AudienceSetupPage> createState() => _AudienceSetupPageState();
}

class _AudienceSetupPageState extends ConsumerState<AudienceSetupPage> {
  LanguageOption? selectedLanguage;
  bool isJoining = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HermesAppBar(customTitle: 'Join Session'),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Session status header
                const SessionHeader(),

                // Main content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(HermesSpacing.md),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Session join form
                        SessionJoinForm(
                          isLoading: isJoining,
                          onJoin: _handleJoinSession,
                        ),

                        const SizedBox(height: HermesSpacing.lg),

                        // Language selection section
                        _buildLanguageSelectionSection(),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Joining loading overlay
            if (isJoining) _buildJoiningLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  Widget _buildLanguageSelectionSection() {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header
        Row(
          children: [
            Icon(
              Icons.translate_rounded,
              size: 20,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: HermesSpacing.sm),
            Text(
              'Select Translation Language',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),

        const SizedBox(height: HermesSpacing.xs),

        Text(
          'Choose the language you want to hear translations in',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),

        const SizedBox(height: HermesSpacing.md),

        // Language selector
        LanguageSelector(
          selectedLanguageCode: selectedLanguage?.code,
          maxHeight: 300,
          onLanguageSelected: (language) {
            setState(() => selectedLanguage = language);
          },
        ),

        // Selected language preview
        if (selectedLanguage != null) ...[
          const SizedBox(height: HermesSpacing.md),
          _buildSelectedLanguagePreview(),
        ],

        const SizedBox(height: HermesSpacing.lg),

        // Helpful tip
        _buildHelpfulTip(),
      ],
    );
  }

  Widget _buildSelectedLanguagePreview() {
    final theme = Theme.of(context);

    return ElevatedCard(
      backgroundColor: theme.colorScheme.primaryContainer.withValues(
        alpha: 0.3,
      ),
      elevation: 1,
      child: Row(
        children: [
          Text(selectedLanguage!.flag, style: const TextStyle(fontSize: 24)),
          const SizedBox(width: HermesSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Selected Language',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
              Text(
                selectedLanguage!.name,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Spacer(),
          Icon(
            Icons.check_circle_rounded,
            color: theme.colorScheme.primary,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildHelpfulTip() {
    final theme = Theme.of(context);

    return ElevatedCard(
      backgroundColor: theme.colorScheme.surfaceContainerHighest.withValues(
        alpha: 0.5,
      ),
      elevation: 1,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lightbulb_outline,
            size: 20,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: HermesSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tip',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: HermesSpacing.xs),
                Text(
                  'You can change your translation language anytime during the session from the settings menu.',
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

  /// Joining session loading overlay
  Widget _buildJoiningLoadingOverlay() {
    final theme = Theme.of(context);

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: ElevatedCard(
          elevation: 8,
          margin: const EdgeInsets.all(HermesSpacing.lg),
          padding: const EdgeInsets.all(HermesSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Loading animation
              SizedBox(
                width: 60,
                height: 60,
                child: CircularProgressIndicator(
                  strokeWidth: 4,
                  valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                ),
              ),

              const SizedBox(height: HermesSpacing.lg),

              // Status text
              Text(
                'Joining Session',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: HermesSpacing.sm),

              Text(
                'Connecting to the speaker and preparing translations...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: HermesSpacing.lg),

              // Simple progress indicator
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: HermesSpacing.md,
                  vertical: HermesSpacing.sm,
                ),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primaryContainer.withValues(
                    alpha: 0.3,
                  ),
                  borderRadius: BorderRadius.circular(HermesSpacing.sm),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (selectedLanguage != null) ...[
                      Text(
                        selectedLanguage!.flag,
                        style: const TextStyle(fontSize: 20),
                      ),
                      const SizedBox(width: HermesSpacing.sm),
                    ],
                    Text(
                      'Translation: ${selectedLanguage?.name ?? 'Selected Language'}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleJoinSession() async {
    if (selectedLanguage == null) {
      _showLanguageRequiredSnackBar();
      return;
    }

    setState(() => isJoining = true);

    try {
      final sessionCode = ref.read(sessionCodeInputProvider).value;

      // Join the session
      await ref
          .read(hermesControllerProvider.notifier)
          .joinSession(sessionCode);

      // Navigate to audience active page with language preferences
      if (mounted) {
        context.go(
          '/audience-active',
          extra: {
            'targetLanguageCode': selectedLanguage!.code,
            'targetLanguageName': selectedLanguage!.name,
            'languageFlag': selectedLanguage!.flag,
          },
        );
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => isJoining = false);
      }
    }
  }

  void _showLanguageRequiredSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white),
            SizedBox(width: HermesSpacing.sm), // Use spacing constant
            Text('Please select a language first'),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesSpacing.sm),
        ),
      ),
    );
  }

  void _showErrorSnackBar(String error) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: HermesSpacing.sm), // Use spacing constant
            Expanded(child: Text('Failed to join session: $error')),
          ],
        ),
        backgroundColor: Theme.of(context).colorScheme.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(HermesSpacing.sm),
        ),
      ),
    );
  }
}
