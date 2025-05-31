// lib/features/session/presentation/pages/active_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/features/app/presentation/widgets/hermes_app_bar.dart';
import '../widgets/organisms/session_header.dart';
import '../widgets/organisms/speaker_control_panel.dart';
import '../widgets/organisms/translation_feed.dart';
import '../widgets/organisms/audience_display.dart';

/// Active session page that adapts based on user role (speaker vs audience).
/// Shows appropriate interface and controls for each session participant.
class ActiveSessionPage extends ConsumerWidget {
  const ActiveSessionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionService = getIt<ISessionService>();
    final sessionState = ref.watch(hermesControllerProvider);

    return Scaffold(
      appBar: HermesAppBar(),
      body: SafeArea(
        child: sessionState.when(
          data:
              (state) => Column(
                children: [
                  // Session header with current session code
                  SessionHeader(
                    sessionCode: sessionService.currentSession?.sessionId,
                    showSessionCode: true,
                  ),

                  // Role-specific content
                  Expanded(
                    child:
                        sessionService.isSpeaker
                            ? _buildSpeakerView(sessionService)
                            : _buildAudienceView(sessionService),
                  ),

                  // Session controls
                  _buildSessionControls(context, ref),
                ],
              ),
          loading: () => const _ActiveSessionSkeleton(),
          error:
              (error, _) => _ActiveSessionError(
                error: error,
                onRetry: () => context.go('/'),
              ),
        ),
      ),
    );
  }

  Widget _buildSpeakerView(ISessionService sessionService) {
    return Column(
      children: [
        // Speaker control panel
        SpeakerControlPanel(
          languageCode: sessionService.currentSession?.languageCode ?? 'en-US',
        ),

        // Translation feed
        const Expanded(child: TranslationFeed()),
      ],
    );
  }

  Widget _buildAudienceView(ISessionService sessionService) {
    // For now, using placeholder values - in a real app, these would come from user preferences
    return AudienceDisplay(
      targetLanguageCode: 'es-ES',
      targetLanguageName: 'Spanish',
      languageFlag: '🇪🇸',
    );
  }

  Widget _buildSessionControls(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: () => _handleLeaveSession(context, ref),
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Leave Session'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleLeaveSession(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showLeaveConfirmation(context);
    if (confirmed && context.mounted) {
      await ref.read(hermesControllerProvider.notifier).stop();
      if (context.mounted) {
        context.go('/');
      }
    }
  }

  Future<bool> _showLeaveConfirmation(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Leave Session'),
                content: const Text(
                  'Are you sure you want to leave this session?',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Leave'),
                  ),
                ],
              ),
        ) ??
        false;
  }
}

class _ActiveSessionSkeleton extends StatelessWidget {
  const _ActiveSessionSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(height: 80, color: Colors.grey.withValues(alpha: 0.3)),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ],
    );
  }
}

class _ActiveSessionError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ActiveSessionError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Session Error',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Back to Home'),
            ),
          ],
        ),
      ),
    );
  }
}
