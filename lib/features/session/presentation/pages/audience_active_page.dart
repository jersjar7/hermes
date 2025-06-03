// lib/features/session/presentation/pages/audience_active_page.dart

import 'package:flutter/material.dart';
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
import '../widgets/organisms/session_header.dart';
import '../widgets/organisms/audience_display.dart';

/// Active session page specifically for AUDIENCE MEMBERS.
/// Features full-screen translation display with minimal distractions.
class AudienceActivePage extends ConsumerStatefulWidget {
  /// Target language for translations (TODO: get from user preferences)
  final String? targetLanguageCode;
  final String? targetLanguageName;
  final String? languageFlag;

  const AudienceActivePage({
    super.key,
    this.targetLanguageCode,
    this.targetLanguageName,
    this.languageFlag,
  });

  @override
  ConsumerState<AudienceActivePage> createState() => _AudienceActivePageState();
}

class _AudienceActivePageState extends ConsumerState<AudienceActivePage> {
  // Default values - TODO: replace with user preferences
  late final String _targetLanguageCode;
  late final String _targetLanguageName;
  late final String _languageFlag;

  @override
  void initState() {
    super.initState();

    // Set defaults - TODO: get from user preferences/navigation params
    _targetLanguageCode = widget.targetLanguageCode ?? 'es-ES';
    _targetLanguageName = widget.targetLanguageName ?? 'Spanish';
    _languageFlag = widget.languageFlag ?? '🇪🇸';
  }

  @override
  Widget build(BuildContext context) {
    final sessionService = getIt<ISessionService>();
    final sessionState = ref.watch(hermesControllerProvider);

    // Ensure this page is only used by audience members
    if (sessionService.isSpeaker) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacementNamed('/speaker-active');
      });
      return const SizedBox.shrink();
    }

    return Scaffold(
      appBar: const HermesAppBar(
        customTitle: 'Live Translation',
        customBackTitle: 'Leave Session',
        customBackMessage: 'Are you sure you want to leave this session?',
      ),
      body: SafeArea(
        child: sessionState.when(
          data: (state) => _buildAudienceLayout(state),
          loading: () => const _AudienceActiveSkeleton(),
          error:
              (error, _) => _AudienceActiveError(
                error: error,
                onRetry: () => _navigateToHome(),
              ),
        ),
      ),
    );
  }

  /// Clean audience layout with full-screen translation display
  Widget _buildAudienceLayout(state) {
    return Column(
      children: [
        // Minimal session header
        const SessionHeader(showMinimal: true),

        // Main content - full-screen translation display
        Expanded(
          child: AudienceDisplay(
            targetLanguageCode: _targetLanguageCode,
            targetLanguageName: _targetLanguageName,
            languageFlag: _languageFlag,
          ),
        ),

        // Simple bottom controls
        _buildAudienceBottomControls(),
      ],
    );
  }

  /// Simple audience controls - just leave session
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
            // Leave Session button using GhostButton
            GhostButton(
              label: 'Leave Session',
              icon: Icons.exit_to_app_rounded,
              isDestructive: true,
              onPressed: _showLeaveSessionDialog,
            ),

            const SizedBox(width: HermesSpacing.lg),

            // Connection Info button using GhostButton
            GhostButton(
              label: 'Connection Info',
              icon: Icons.info_outline_rounded,
              onPressed: _showConnectionInfo,
            ),
          ],
        ),
      ),
    );
  }

  /// Show leave session confirmation dialog using atomic design
  Future<void> _showLeaveSessionDialog() async {
    // ✨ Using the improved LeaveSessionDialog component
    final confirmed = await LeaveSessionDialog.show(context: context);

    // Check the result and call _leaveSession if confirmed
    if (confirmed == true && mounted) {
      await _leaveSession();
    }
  }

  /// Show connection info dialog using atomic design components
  void _showConnectionInfo() {
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
              title: const Text('Connection Information'),
              content: ElevatedCard(
                elevation: 0,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // ✨ Using new InfoSection pattern with DetailRow atoms
                      _buildInfoSection('Session Details', [
                        DetailRow(
                          label: 'Session Code',
                          value:
                              sessionService.currentSession?.sessionId ??
                              'Unknown',
                        ),
                        DetailRow(
                          label: 'Translation Language',
                          value: _targetLanguageName,
                        ),
                        DetailRow(
                          label: 'Status',
                          value: _getStatusText(state.status),
                        ),
                      ]),

                      const SizedBox(height: HermesSpacing.lg),

                      _buildInfoSection('Translation Info', [
                        DetailRow(
                          label: 'Total Listeners',
                          value: '${state.audienceCount}',
                        ),
                        if (state.languageDistribution.isNotEmpty)
                          DetailRow(
                            label: 'Active Languages',
                            value: state.languageDistribution.keys.join(', '),
                          ),
                        if (state.lastTranslation != null)
                          DetailRow(
                            label: 'Last Translation',
                            value:
                                '"${_truncateText(state.lastTranslation!, 50)}"',
                          ),
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
              ],
            ),
      );
    });
  }

  /// ✨ Simplified info section builder (structural component)
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

  String _getStatusText(dynamic status) {
    final statusStr = status.toString().split('.').last;
    switch (statusStr) {
      case 'idle':
        return 'Waiting to start';
      case 'listening':
        return 'Speaker is talking';
      case 'translating':
        return 'Translating speech';
      case 'buffering':
        return 'Preparing translation';
      case 'countdown':
        return 'Starting soon';
      case 'speaking':
        return 'Playing translation';
      case 'paused':
        return 'Session paused';
      case 'error':
        return 'Connection error';
      default:
        return 'Unknown';
    }
  }

  String _truncateText(String text, int maxLength) {
    if (text.length <= maxLength) return text;
    return '${text.substring(0, maxLength)}...';
  }

  /// Leave the session
  Future<void> _leaveSession() async {
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
                Text('Left session successfully'),
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
      print('Failed to leave session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to leave session: $e'),
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

/// Loading skeleton for audience active page
class _AudienceActiveSkeleton extends StatelessWidget {
  const _AudienceActiveSkeleton();

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
                width: 150,
                height: 16,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),

        // Main content skeleton - large translation area
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
                  // Language indicator skeleton
                  Container(
                    width: 200,
                    height: 60,
                    decoration: BoxDecoration(
                      color: theme.colorScheme.outline.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(HermesSpacing.md),
                    ),
                  ),

                  const SizedBox(height: HermesSpacing.xl),

                  // Loading indicator
                  CircularProgressIndicator(strokeWidth: 3),

                  const SizedBox(height: HermesSpacing.lg),

                  Text(
                    'Connecting to translation session...',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: HermesSpacing.sm),

                  Text(
                    'Please wait while we connect you to the speaker',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                    textAlign: TextAlign.center,
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 140,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(HermesSpacing.sm),
                ),
              ),
              const SizedBox(width: HermesSpacing.lg),
              Container(
                width: 120,
                height: 48,
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

/// Error state for audience active page
class _AudienceActiveError extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;

  const _AudienceActiveError({required this.error, required this.onRetry});

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
              Icons.wifi_off_rounded,
              size: 80,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: HermesSpacing.lg),
            Text(
              'Connection Lost',
              style: theme.textTheme.headlineSmall?.copyWith(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: HermesSpacing.md),
            Text(
              'Unable to receive translations. Please check your internet connection.',
              style: theme.textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HermesSpacing.sm),
            Text(
              'The session may have ended or your connection was interrupted.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: HermesSpacing.xl),
            Column(
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Implement retry connection logic
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Retry functionality coming soon'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.refresh_rounded),
                  label: const Text('Try Again'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HermesSpacing.lg,
                      vertical: HermesSpacing.md,
                    ),
                  ),
                ),
                const SizedBox(height: HermesSpacing.md),
                OutlinedButton.icon(
                  onPressed: onRetry,
                  icon: const Icon(Icons.home_rounded),
                  label: const Text('Back to Home'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: HermesSpacing.lg,
                      vertical: HermesSpacing.md,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
