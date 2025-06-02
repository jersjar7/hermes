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

/// Active session page with optimized layout for both speaker and audience modes.
/// Features proper space allocation ensuring all components are visible.
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
              return _buildSpeakerLayout(sessionService, state);
            } else {
              return _buildAudienceLayout(sessionService, state);
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

  /// Speaker layout with optimized space allocation for transcript visibility
  Widget _buildSpeakerLayout(ISessionService sessionService, state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate space allocation
        const headerHeight = 50.0;
        const statusBarHeight = 60.0;
        const sessionControlsHeight = 80.0;
        const speakerControlHeight = 100.0;
        const spacing = HermesSpacing.sm * 4;

        final fixedHeight =
            headerHeight +
            statusBarHeight +
            sessionControlsHeight +
            speakerControlHeight +
            spacing;
        final availableHeight = constraints.maxHeight;
        final transcriptHeight = (availableHeight - fixedHeight).clamp(
          250.0,
          double.infinity,
        );

        return Column(
          children: [
            // 1. Minimal session header
            SizedBox(
              height: headerHeight,
              child: const SessionHeader(showMinimal: true),
            ),

            // 2. Compact speaker controls
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HermesSpacing.md,
                HermesSpacing.sm,
                HermesSpacing.md,
                0,
              ),
              child: SpeakerControlPanel(
                languageCode:
                    sessionService.currentSession?.languageCode ?? 'en-US',
                isCompact: true,
              ),
            ),

            const SizedBox(height: HermesSpacing.sm),

            // 3. Transcript chat box with guaranteed space
            Container(
              height: transcriptHeight,
              margin: const EdgeInsets.symmetric(horizontal: HermesSpacing.md),
              child: const TranscriptChatBox(),
            ),

            const SizedBox(height: HermesSpacing.sm),

            // 4. Session control buttons
            _buildSessionControlsRow(),

            // 5. Status bar
            _buildSpeakerStatusBar(sessionService, state),
          ],
        );
      },
    );
  }

  /// Audience layout with full-screen translation display
  Widget _buildAudienceLayout(ISessionService sessionService, state) {
    return Column(
      children: [
        const SessionHeader(showMinimal: true),
        Expanded(
          child: AudienceDisplay(
            targetLanguageCode: 'es-ES', // TODO: Get from user preferences
            targetLanguageName: 'Spanish', // TODO: Get from user preferences
            languageFlag: '🇪🇸', // TODO: Get from user preferences
          ),
        ),
        _buildAudienceBottomControls(),
      ],
    );
  }

  /// Session control buttons row for speakers
  Widget _buildSessionControlsRow() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(
        horizontal: HermesSpacing.md,
        vertical: HermesSpacing.sm,
      ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HermesSpacing.sm),
                ),
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HermesSpacing.sm),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Speaker status bar at bottom
  Widget _buildSpeakerStatusBar(ISessionService sessionService, state) {
    final sessionCode = sessionService.currentSession?.sessionId ?? '';
    final duration =
        sessionStartTime != null
            ? DateTime.now().difference(sessionStartTime!)
            : Duration.zero;

    return SizedBox(
      height: 60,
      child: SessionStatusBar(
        sessionCode: sessionCode,
        sessionDuration: duration,
        audienceCount: state.audienceCount,
        languageDistribution: state.languageDistribution,
        onSessionCodeTap: () => _copySessionCode(sessionCode),
      ),
    );
  }

  /// Audience bottom controls
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
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: () => _handleManualExit(),
              icon: Icon(
                Icons.exit_to_app_rounded,
                color: Theme.of(context).colorScheme.error,
              ),
              label: Text(
                'Leave Session',
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
                padding: const EdgeInsets.symmetric(
                  horizontal: HermesSpacing.lg,
                  vertical: HermesSpacing.sm,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(HermesSpacing.sm),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Copy session code to clipboard
  Future<void> _copySessionCode(String sessionCode) async {
    if (sessionCode.isNotEmpty) {
      await Clipboard.setData(ClipboardData(text: sessionCode));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: HermesSpacing.sm),
                Text('Session code copied: $sessionCode'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HermesSpacing.sm),
            ),
          ),
        );
      }
    }
  }

  /// Show end session confirmation dialog
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HermesSpacing.md),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Theme.of(context).colorScheme.error,
                  size: 24,
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
                const SizedBox(height: HermesSpacing.md),
                const Text('This will:'),
                const SizedBox(height: HermesSpacing.xs),
                const Text('• Stop all translation services'),
                if (audienceCount > 0) ...[
                  Text('• Disconnect $audienceCount audience members'),
                ],
                const Text('• Delete the session permanently'),
                const SizedBox(height: HermesSpacing.md),
                Container(
                  padding: const EdgeInsets.all(HermesSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.errorContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(HermesSpacing.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.error,
                      ),
                      const SizedBox(width: HermesSpacing.xs),
                      Expanded(
                        child: Text(
                          'This action cannot be undone.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
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

  /// Show session details dialog
  void _showSessionDetails() {
    final sessionState = ref.read(hermesControllerProvider);
    final sessionService = getIt<ISessionService>();

    sessionState.whenData((state) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(HermesSpacing.md),
              ),
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

                    const SizedBox(height: HermesSpacing.lg),

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
                              bottom: 4,
                            ),
                            child: Text(
                              '• ${entry.key}: ${entry.value} listeners',
                              style: const TextStyle(fontSize: 14),
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
                  child: const Text('Copy Code'),
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
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
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

    final languageNames = {
      'en-US': 'English (US)',
      'es-ES': 'Spanish (Spain)',
      'fr-FR': 'French (France)',
      'de-DE': 'German (Germany)',
      'it-IT': 'Italian (Italy)',
      'pt-BR': 'Portuguese (Brazil)',
      'ru-RU': 'Russian (Russia)',
      'ja-JP': 'Japanese (Japan)',
      'ko-KR': 'Korean (Korea)',
      'zh-CN': 'Chinese (China)',
    };

    return languageNames[languageCode] ?? languageCode;
  }

  String _getStatusText(dynamic status) {
    final statusStr = status.toString().split('.').last;
    switch (statusStr) {
      case 'idle':
        return 'Ready';
      case 'listening':
        return 'Live';
      case 'translating':
        return 'Processing';
      case 'buffering':
        return 'Buffering';
      case 'countdown':
        return 'Starting';
      case 'speaking':
        return 'Playing';
      case 'paused':
        return 'Paused';
      case 'error':
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

  /// End the session
  Future<void> _endSession() async {
    try {
      await ref.read(hermesControllerProvider.notifier).stop();
      if (mounted) {
        // Navigate to home with a success message
        Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                SizedBox(width: HermesSpacing.sm),
                Text('Session ended successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HermesSpacing.sm),
            ),
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
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HermesSpacing.sm),
            ),
          ),
        );
      }
    }
  }

  /// Handle manual exit for audience
  Future<void> _handleManualExit() async {
    await context.smartGoBack(ref);
  }
}

/// Loading skeleton while session state loads
class _ActiveSessionSkeleton extends StatelessWidget {
  const _ActiveSessionSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        // Header skeleton
        Container(
          height: 50,
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
              borderRadius: BorderRadius.circular(HermesSpacing.md),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(strokeWidth: 2),
                  const SizedBox(height: HermesSpacing.md),
                  Text(
                    'Loading session...',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Bottom controls skeleton
        Container(
          height: 80,
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.all(HermesSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(HermesSpacing.sm),
                  ),
                ),
              ),
              const SizedBox(width: HermesSpacing.md),
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(HermesSpacing.sm),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Error state when session fails to load
class _ActiveSessionError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _ActiveSessionError({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HermesSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 80,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: HermesSpacing.lg),
            Text(
              'Session Error',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: HermesSpacing.md),
            Text(
              'Unable to connect to the session. Please check your connection and try again.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HermesSpacing.xl),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.home_rounded),
              label: const Text('Back to Home'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: HermesSpacing.lg,
                  vertical: HermesSpacing.md,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
