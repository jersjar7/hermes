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
import '../widgets/organisms/transcript_chat_box.dart';

/// Active session page with redesigned speaker view:
/// 1. App bar
/// 2. Speaker controls (compact)
/// 3. Fixed-size transcript chat box
/// 4. Session control buttons row
/// 5. Session status bar
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

                  // Main content area - different layout for speaker vs audience
                  if (sessionService.isSpeaker)
                    ..._buildSpeakerLayout(sessionService, state)
                  else
                    Expanded(child: _buildAudienceView(sessionService, state)),

                  // Bottom controls based on role
                  if (sessionService.isSpeaker)
                    _buildSpeakerStatusBar(sessionService, state)
                  else
                    _buildAudienceBottomControls(),
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

  /// NEW: Speaker layout with fixed structure
  List<Widget> _buildSpeakerLayout(ISessionService sessionService, state) {
    return [
      // 1. Compact speaker controls
      Padding(
        padding: const EdgeInsets.fromLTRB(
          HermesSpacing.md,
          HermesSpacing.sm,
          HermesSpacing.md,
          0,
        ),
        child: SpeakerControlPanel(
          languageCode: sessionService.currentSession?.languageCode ?? 'en-US',
          isCompact: true, // NEW: compact mode
        ),
      ),

      const SizedBox(height: HermesSpacing.sm),

      // 2. Fixed-size transcript chat box (takes remaining space)
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: HermesSpacing.md),
          child: TranscriptChatBox(),
        ),
      ),

      const SizedBox(height: HermesSpacing.sm),

      // 3. Session control buttons row
      _buildSessionControlsRow(),
    ];
  }

  Widget _buildAudienceView(ISessionService sessionService, state) {
    return AudienceDisplay(
      targetLanguageCode: 'es-ES', // TODO: Get from user preferences
      targetLanguageName: 'Spanish', // TODO: Get from user preferences
      languageFlag: '🇪🇸', // TODO: Get from user preferences
    );
  }

  /// NEW: Clean session controls row (separate from speaking controls)
  Widget _buildSessionControlsRow() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HermesSpacing.md,
        vertical: HermesSpacing.sm,
      ),
      child: Row(
        children: [
          // End Session (primary destructive action)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showEndSessionDialog,
              icon: Icon(
                Icons.stop_rounded,
                color: Theme.of(context).colorScheme.error,
                size: 20,
              ),
              label: Text(
                'End Session',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: Theme.of(context).colorScheme.error,
                  width: 2,
                ),
                padding: const EdgeInsets.symmetric(vertical: HermesSpacing.sm),
              ),
            ),
          ),

          const SizedBox(width: HermesSpacing.md),

          // Session Info (secondary action)
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _showSessionDetails,
              icon: const Icon(Icons.info_outline, size: 20),
              label: const Text(
                'Session Info',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: HermesSpacing.sm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Speaker status bar (compact version)
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

  /// Simple audience controls
  Widget _buildAudienceBottomControls() {
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
          OutlinedButton.icon(
            onPressed: () => _handleManualExit(),
            icon: Icon(
              Icons.exit_to_app,
              color: Theme.of(context).colorScheme.error,
            ),
            label: Text(
              'Leave Session',
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: Theme.of(context).colorScheme.error),
            ),
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
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                const SizedBox(width: HermesSpacing.sm),
                Text('Session code copied: $sessionCode'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  /// IMPROVED: Better end session dialog with clear consequences
  Future<void> _showEndSessionDialog() async {
    final sessionState = ref.read(hermesControllerProvider);
    final audienceCount = sessionState.when(
      data: (state) => state.audienceCount,
      loading: () => 0,
      error: (_, __) => 0,
    );

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                ),
                const SizedBox(width: HermesSpacing.sm),
                const Text('End Session'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to end this session?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: HermesSpacing.sm),
                const Text('This will:'),
                const SizedBox(height: HermesSpacing.xs),
                const Text('• Stop all translation services'),
                if (audienceCount > 0) ...[
                  Text('• Disconnect $audienceCount audience members'),
                ],
                const Text('• Delete the session permanently'),
                const SizedBox(height: HermesSpacing.sm),
                Container(
                  padding: const EdgeInsets.all(HermesSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(HermesSpacing.sm),
                  ),
                  child: Text(
                    'This action cannot be undone.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: const Text('End Session'),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      await _endSession();
    }
  }

  /// IMPROVED: Better session info dialog
  void _showSessionDetails() {
    final sessionState = ref.read(hermesControllerProvider);
    final sessionService = getIt<ISessionService>();

    sessionState.whenData((state) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Session Information'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildInfoSection('Session Details', [
                      _buildDetailRow(
                        'Session Code',
                        sessionService.currentSession?.sessionId ?? 'Unknown',
                      ),
                      _buildDetailRow(
                        'Speaking Language',
                        _getLanguageName(
                          sessionService.currentSession?.languageCode,
                        ),
                      ),
                      _buildDetailRow('Status', _getStatusText(state.status)),
                      if (sessionStartTime != null)
                        _buildDetailRow(
                          'Duration',
                          _formatDuration(
                            DateTime.now().difference(sessionStartTime!),
                          ),
                        ),
                    ]),

                    const SizedBox(height: HermesSpacing.md),

                    _buildInfoSection('Audience', [
                      _buildDetailRow(
                        'Total Listeners',
                        '${state.audienceCount}',
                      ),
                      if (state.languageDistribution.isNotEmpty) ...[
                        const SizedBox(height: HermesSpacing.sm),
                        const Text(
                          'Translation Languages:',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: HermesSpacing.xs),
                        ...state.languageDistribution.entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(
                              left: HermesSpacing.md,
                              bottom: HermesSpacing.xs,
                            ),
                            child: Text(
                              '• ${entry.key}: ${entry.value} listeners',
                            ),
                          ),
                        ),
                      ],
                    ]),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    _copySessionCode(
                      sessionService.currentSession?.sessionId ?? '',
                    );
                  },
                  child: const Text('Copy Session Code'),
                ),
              ],
            ),
      );
    });
  }

  Widget _buildInfoSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        const SizedBox(height: HermesSpacing.sm),
        ...children,
      ],
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HermesSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              '$label:',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _getLanguageName(String? languageCode) {
    if (languageCode == null) return 'Unknown';
    // Simple mapping - in a real app, you'd use the language helpers
    switch (languageCode) {
      case 'en-US':
        return 'English (US)';
      case 'es-ES':
        return 'Spanish (Spain)';
      case 'fr-FR':
        return 'French (France)';
      case 'de-DE':
        return 'German (Germany)';
      default:
        return languageCode;
    }
  }

  String _getStatusText(state) {
    // Use the same status text from the original file
    switch (state.runtimeType.toString()) {
      case 'HermesStatus.idle':
        return 'Ready';
      case 'HermesStatus.listening':
        return 'Live';
      case 'HermesStatus.translating':
        return 'Processing';
      case 'HermesStatus.buffering':
        return 'Buffering';
      case 'HermesStatus.countdown':
        return 'Starting';
      case 'HermesStatus.speaking':
        return 'Playing';
      case 'HermesStatus.paused':
        return 'Paused';
      case 'HermesStatus.error':
        return 'Error';
      default:
        return 'Unknown';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  Future<void> _endSession() async {
    try {
      await ref.read(hermesControllerProvider.notifier).stop();
      if (mounted) {
        // Navigate to home with a success message
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session ended successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Failed to end session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to end session: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  /// Handles manual exit (e.g., from audience controls)
  Future<void> _handleManualExit() async {
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

        // Bottom controls skeleton
        Container(
          height: 100,
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.all(HermesSpacing.md),
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 40,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: HermesSpacing.sm),
              Container(
                width: double.infinity,
                height: 40,
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
