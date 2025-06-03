// lib/features/session/presentation/pages/speaker_active_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/presentation/widgets/buttons/ghost_button.dart';
import 'package:hermes/core/presentation/widgets/cards/elevated_card.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/features/app/presentation/widgets/hermes_app_bar.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import '../widgets/atoms/detail_row.dart';
import '../widgets/molecules/confirmation_dialog.dart';
import '../widgets/organisms/speaker_control_panel.dart';
import '../widgets/organisms/session_status_bar.dart';
import '../widgets/organisms/transcript_chat_box.dart';

/// Active session page specifically for SPEAKERS.
/// Features optimized layout with transcript chat box and speaking controls.
class SpeakerActivePage extends ConsumerStatefulWidget {
  const SpeakerActivePage({super.key});

  @override
  ConsumerState<SpeakerActivePage> createState() => _SpeakerActivePageState();
}

class _SpeakerActivePageState extends ConsumerState<SpeakerActivePage> {
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

    // Ensure this page is only used by speakers
    if (!sessionService.isSpeaker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/audience-active');
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: const HermesAppBar(
        customTitle: 'Live Session',
        customBackTitle: 'End Session',
        customBackMessage:
            'Are you sure you want to end this session? All audience members will be disconnected.',
      ),
      body: SafeArea(
        child: sessionState.when(
          data: (state) => _buildSpeakerLayout(sessionService, state),
          loading: () => const _SpeakerActiveSkeleton(),
          error:
              (error, _) => _SpeakerActiveError(
                error: error,
                onRetry: () => _navigateToHome(),
              ),
        ),
      ),
    );
  }

  /// Speaker layout with optimized space allocation for transcript visibility
  Widget _buildSpeakerLayout(ISessionService sessionService, state) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate space allocation to ensure transcript is visible
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
          250.0, // Minimum height for transcript
          double.infinity,
        );

        return Column(
          children: [
            // 1. Compact speaker controls
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

            // 2. Transcript chat box with guaranteed space
            Container(
              height: transcriptHeight,
              margin: const EdgeInsets.symmetric(horizontal: HermesSpacing.md),
              child: const TranscriptChatBox(),
            ),

            const SizedBox(height: HermesSpacing.sm),

            // 3. Session control buttons
            _buildSessionControlsRow(),

            // 4. Status bar
            _buildSpeakerStatusBar(sessionService, state),
          ],
        );
      },
    );
  }

  /// Session control buttons row
  Widget _buildSessionControlsRow() {
    return Container(
      height: 80,
      padding: const EdgeInsets.symmetric(
        horizontal: HermesSpacing.md,
        vertical: HermesSpacing.sm,
      ),
      child: Row(
        children: [
          // End Session button using GhostButton
          Expanded(
            child: GhostButton(
              label: 'End Session',
              icon: Icons.stop_rounded,
              isDestructive: true,
              onPressed: _showEndSessionDialog,
            ),
          ),

          const SizedBox(width: HermesSpacing.md),

          // Session Info button using GhostButton
          Expanded(
            child: GhostButton(
              label: 'Session Info',
              icon: Icons.info_outline,
              onPressed: _showSessionDetails,
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

  /// Show end session confirmation dialog using improved atomic design
  Future<void> _showEndSessionDialog() async {
    final sessionState = ref.read(hermesControllerProvider);
    final audienceCount = sessionState.when(
      data: (state) => state.audienceCount,
      loading: () => 0,
      error: (_, __) => 0,
    );

    // ✨ Using the improved EndSessionDialog component
    final confirmed = await EndSessionDialog.show(
      context: context,
      audienceCount: audienceCount,
    );

    // Check the result and call _endSession if confirmed
    if (confirmed == true && mounted) {
      await _endSession();
    }
  }

  /// Show session details dialog using atomic design
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
              content: ElevatedCard(
                elevation: 0,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✨ Using new InfoSection pattern
                      _buildInfoSection('Session Details', [
                        // ✨ Using DetailRow atoms instead of custom widgets
                        DetailRow(
                          label: 'Session Code',
                          value:
                              sessionService.currentSession?.sessionId ??
                              'Unknown',
                        ),
                        DetailRow(
                          label: 'Speaking Language',
                          value: _getLanguageName(
                            sessionService.currentSession?.languageCode,
                          ),
                        ),
                        DetailRow(
                          label: 'Status',
                          value: _getStatusText(state.status),
                        ),
                        if (sessionStartTime != null)
                          DetailRow(
                            label: 'Duration',
                            value: _formatDuration(
                              DateTime.now().difference(sessionStartTime!),
                            ),
                          ),
                      ]),

                      const SizedBox(height: HermesSpacing.lg),

                      _buildInfoSection('Audience', [
                        DetailRow(
                          label: 'Total Listeners',
                          value: '${state.audienceCount}',
                        ),
                        if (state.languageDistribution.isNotEmpty) ...[
                          const SizedBox(height: HermesSpacing.sm),
                          const Text(
                            'Translation Languages:',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: HermesSpacing.xs),
                          // ✨ Using CompactDetailRow for language breakdown
                          ...state.languageDistribution.entries.map(
                            (entry) => CompactDetailRow(
                              label: entry.key,
                              value: '${entry.value} listeners',
                              icon: Icons.people_rounded,
                            ),
                          ),
                        ],
                      ]),
                    ],
                  ),
                ),
              ),
              actions: [
                // ✨ Using GhostButton instead of TextButton
                GhostButton(
                  label: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                ),
                GhostButton(
                  label: 'Copy Code',
                  onPressed: () {
                    Navigator.of(context).pop();
                    _copySessionCode(
                      sessionService.currentSession?.sessionId ?? '',
                    );
                  },
                ),
              ],
            ),
      );
    });
  }

  /// ✨ Simplified info section builder (still needed for structure)
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
        _navigateToHome();
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

  /// Navigate to home page
  void _navigateToHome() {
    Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
  }
}

/// Loading skeleton for speaker active page
class _SpeakerActiveSkeleton extends StatelessWidget {
  const _SpeakerActiveSkeleton();

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

        // Speaker control skeleton
        Container(
          height: 100,
          margin: const EdgeInsets.symmetric(horizontal: HermesSpacing.md),
          decoration: BoxDecoration(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(HermesSpacing.md),
          ),
        ),

        const SizedBox(height: HermesSpacing.md),

        // Transcript skeleton
        Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: HermesSpacing.md),
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
          height: 140, // Controls + status bar
          color: theme.colorScheme.surface,
          padding: const EdgeInsets.all(HermesSpacing.md),
          child: Column(
            children: [
              Row(
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
              const SizedBox(height: HermesSpacing.md),
              Container(
                height: 60,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(HermesSpacing.sm),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Error state for speaker active page
class _SpeakerActiveError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _SpeakerActiveError({required this.error, required this.onRetry});

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
