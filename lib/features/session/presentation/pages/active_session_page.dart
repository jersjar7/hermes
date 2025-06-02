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

/// Active session page with redesigned speaker view
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
        customBackTitle:
            sessionService.isSpeaker ? 'End Session' : 'Leave Session',
        customBackMessage:
            sessionService.isSpeaker
                ? 'Are you sure you want to end this session? All audience members will be disconnected.'
                : 'Are you sure you want to leave this session?',
      ),
      body: SafeArea(
        child: sessionState.when(
          data: (state) {
            if (sessionService.isSpeaker) {
              // SPEAKER LAYOUT
              return Column(
                children: [
                  // Session header
                  const SessionHeader(showMinimal: true),

                  // Main content area
                  Expanded(
                    child: Column(
                      children: [
                        // 1. Speaker controls (compact)
                        Padding(
                          padding: const EdgeInsets.all(HermesSpacing.md),
                          child: SpeakerControlPanel(
                            languageCode:
                                sessionService.currentSession?.languageCode ??
                                'en-US',
                            isCompact: true,
                          ),
                        ),

                        // 2. Transcript box (expands to fill remaining space)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: HermesSpacing.md,
                            ),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.red, width: 3),
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.chat,
                                      size: 48,
                                      color: Colors.red,
                                    ),
                                    SizedBox(height: 16),
                                    Text(
                                      'TRANSCRIPT BOX SPACE',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    SizedBox(height: 8),
                                    Text(
                                      'This should be visible!',
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),

                        // 3. Session control buttons
                        _buildSessionControlsRow(),
                      ],
                    ),
                  ),

                  // Session status bar
                  _buildSpeakerStatusBar(sessionService, state),
                ],
              );
            } else {
              // AUDIENCE LAYOUT
              return Column(
                children: [
                  const SessionHeader(showMinimal: true),
                  Expanded(
                    child: AudienceDisplay(
                      targetLanguageCode: 'es-ES',
                      targetLanguageName: 'Spanish',
                      languageFlag: '🇪🇸',
                    ),
                  ),
                  _buildAudienceBottomControls(),
                ],
              );
            }
          },
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

  Widget _buildSessionControlsRow() {
    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      child: Row(
        children: [
          // End Session button
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

          // Session Info button
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
                const Icon(Icons.check_circle, color: Colors.white, size: 20),
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
        Expanded(
          child: Container(
            margin: const EdgeInsets.all(HermesSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
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
