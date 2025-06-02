// lib/features/session/presentation/pages/active_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/navigation/back_navigation_service.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/features/app/presentation/widgets/hermes_app_bar.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import '../widgets/organisms/session_header.dart';
import '../widgets/organisms/speaker_control_panel.dart';
import '../widgets/organisms/session_status_bar.dart';
import '../widgets/organisms/audience_display.dart';

/// Active session page that adapts based on user role (speaker vs audience).
/// Shows appropriate interface and controls for each session participant.
///
/// Key Features:
/// - Role-aware interface (speakers see transcripts, audience sees translations)
/// - Real-time session status and audience tracking for speakers
/// - Simplified, distraction-free interface during active speaking
/// - Proper component separation based on architectural decisions
/// - Now features smart back navigation that handles session cleanup automatically.
class ActiveSessionPage extends ConsumerStatefulWidget {
  const ActiveSessionPage({super.key});

  @override
  ConsumerState<ActiveSessionPage> createState() => _ActiveSessionPageState();
}

class _ActiveSessionPageState extends ConsumerState<ActiveSessionPage> {
  DateTime? sessionStartTime;

  @override
  void initState() {
    super.initState();
    sessionStartTime = DateTime.now();
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = getIt<ISessionService>();
    final sessionState = ref.watch(hermesControllerProvider);

    return Scaffold(
      appBar: HermesAppBar(
        // Custom confirmation messages based on user role
        customBackTitle:
            sessionService.isSpeaker ? 'End Session' : 'Leave Session',
        customBackMessage:
            sessionService.isSpeaker
                ? 'Are you sure you want to end this session? All audience members will be disconnected.'
                : 'Are you sure you want to leave this session?',
      ),
      body: SafeArea(
        child: sessionState.when(
          data:
              (state) => Column(
                children: [
                  // Minimal session header
                  const SessionHeader(showMinimal: true),

                  // Role-specific content
                  Expanded(
                    child:
                        sessionService.isSpeaker
                            ? _buildSpeakerView(sessionService, state)
                            : _buildAudienceView(sessionService, state),
                  ),

                  // Role-specific status/control bars
                  if (sessionService.isSpeaker)
                    _buildSpeakerStatusBar(sessionService, state)
                  else
                    _buildAudienceControls(),
                ],
              ),
          loading: () => const _ActiveSessionSkeleton(),
          error:
              (error, _) => _ActiveSessionError(
                error: error,
                onRetry: () => _handleManualExit(),
              ),
        ),
      ),
    );
  }

  Widget _buildSpeakerView(ISessionService sessionService, state) {
    return Column(
      children: [
        // Main speaker control panel (no translations shown)
        SpeakerControlPanel(
          languageCode: sessionService.currentSession?.languageCode ?? 'en-US',
        ),

        // Optional: Add spacing or other speaker-specific UI elements
        const SizedBox(height: HermesSpacing.sm),
      ],
    );
  }

  Widget _buildAudienceView(ISessionService sessionService, state) {
    // For audience members - show translation interface
    return AudienceDisplay(
      targetLanguageCode: 'es-ES', // TODO: Get from user preferences
      targetLanguageName: 'Spanish', // TODO: Get from user preferences
      languageFlag: '🇪🇸', // TODO: Get from user preferences
    );
  }

  Widget _buildSpeakerStatusBar(ISessionService sessionService, state) {
    final sessionCode = sessionService.currentSession?.sessionId ?? '';
    final duration =
        sessionStartTime != null
            ? DateTime.now().difference(sessionStartTime!)
            : Duration.zero;

    return SessionStatusBar(
      sessionCode: sessionCode,
      sessionDuration: duration,
      audienceCount: state.audienceCount,
      languageDistribution: state.languageDistribution,
      onSessionCodeTap: () => _copySessionCode(sessionCode),
    );
  }

  Widget _buildAudienceControls() {
    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
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
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextButton.icon(
            onPressed: () => _handleManualExit(),
            icon: const Icon(Icons.exit_to_app),
            label: const Text('Leave Session'),
          ),
        ],
      ),
    );
  }

  Future<void> _copySessionCode(String sessionCode) async {
    if (sessionCode.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: sessionCode));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session code copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// Handles manual exit (e.g., from audience controls)
  /// The back button will be handled automatically by HermesAppBar
  Future<void> _handleManualExit() async {
    // Use the same smart navigation logic as the back button
    await context.smartGoBack(ref);
  }
}

/// Loading skeleton for active session page
class _ActiveSessionSkeleton extends StatelessWidget {
  const _ActiveSessionSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header skeleton
        Container(
          height: 60,
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.all(HermesSpacing.md),
          child: Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: HermesSpacing.sm),
              Container(
                width: 120,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: HermesSpacing.md),

        // Main content skeleton
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(HermesSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        // Status bar skeleton
        Container(
          height: 50,
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.all(HermesSpacing.md),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const Spacer(),
              Container(
                width: 80,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Error state for active session page
class _ActiveSessionError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ActiveSessionError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HermesSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: HermesSpacing.md),
            Text(
              'Session Error',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: HermesSpacing.sm),
            Text(
              'Unable to connect to the session. Please check your connection and try again.',
              style: theme.textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HermesSpacing.lg),
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
