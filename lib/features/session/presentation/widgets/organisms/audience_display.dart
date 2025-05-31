// lib/features/session/presentation/widgets/organisms/audience_display.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/core/presentation/widgets/cards/glass_card.dart';
import '../molecules/countdown_widget.dart';
import '../atoms/language_flag.dart';

/// Main display for audience members showing current translation and status.
/// Focuses on the translated content with minimal distractions.
class AudienceDisplay extends ConsumerWidget {
  final String targetLanguageCode;
  final String targetLanguageName;
  final String? languageFlag;

  const AudienceDisplay({
    super.key,
    required this.targetLanguageCode,
    required this.targetLanguageName,
    this.languageFlag,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(hermesControllerProvider);

    return sessionState.when(
      data: (state) => _buildDisplay(context, state),
      loading: () => _buildLoadingState(context),
      error: (error, _) => _buildErrorState(context, error),
    );
  }

  Widget _buildDisplay(BuildContext context, state) {
    return Column(
      children: [
        // Language indicator
        _buildLanguageIndicator(context),

        const SizedBox(height: HermesSpacing.lg),

        // Main content area
        Expanded(child: _buildMainContent(context, state)),

        // Status indicator
        _buildStatusIndicator(context, state),
      ],
    );
  }

  Widget _buildLanguageIndicator(BuildContext context) {
    final theme = Theme.of(context);

    return GlassCard(
      padding: const EdgeInsets.symmetric(
        horizontal: HermesSpacing.lg,
        vertical: HermesSpacing.md,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (languageFlag != null) LanguageFlag(flag: languageFlag!, size: 28),
          const SizedBox(width: HermesSpacing.sm),
          Text(
            'Listening in $targetLanguageName',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(BuildContext context, state) {
    switch (state.status) {
      case HermesStatus.countdown:
        return _buildCountdownContent(context, state);
      case HermesStatus.speaking:
      case HermesStatus.translating:
        return _buildTranslationContent(context, state);
      case HermesStatus.buffering:
        return _buildBufferingContent(context);
      case HermesStatus.paused:
        return _buildPausedContent(context);
      default:
        return _buildWaitingContent(context);
    }
  }

  Widget _buildCountdownContent(BuildContext context, state) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CountdownWidget(seconds: state.countdownSeconds ?? 0, size: 150),
          const SizedBox(height: HermesSpacing.lg),
          Text(
            'Translation starting soon...',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTranslationContent(BuildContext context, state) {
    final theme = Theme.of(context);
    final translation = state.lastTranslation;

    return Center(
      child: GlassCard(
        padding: const EdgeInsets.all(HermesSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (translation != null)
              Text(
                translation,
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
                textAlign: TextAlign.center,
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: HermesSpacing.sm),
                  Text(
                    'Translating...',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.amber,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBufferingContent(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            HermesIcons.buffering,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: HermesSpacing.lg),
          Text(
            'Preparing translation...',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPausedContent(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(HermesIcons.pause, size: 64, color: theme.colorScheme.outline),
          const SizedBox(height: HermesSpacing.lg),
          Text(
            'Session paused',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingContent(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            HermesIcons.listening,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: HermesSpacing.lg),
          Text(
            'Waiting for speaker...',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, state) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      child: Text(
        _getStatusText(state.status),
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.outline,
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: HermesSpacing.lg),
          Text(
            'Connection Error',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(HermesStatus status) {
    switch (status) {
      case HermesStatus.listening:
        return 'Speaker is talking...';
      case HermesStatus.translating:
        return 'Translating speech...';
      case HermesStatus.buffering:
        return 'Buffering translation...';
      case HermesStatus.countdown:
        return 'Translation starting...';
      case HermesStatus.speaking:
        return 'Playing translation...';
      case HermesStatus.paused:
        return 'Session paused';
      default:
        return 'Waiting for session to start';
    }
  }
}
