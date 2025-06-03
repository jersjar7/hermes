// lib/features/session/presentation/pages/audience_active_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/presentation/widgets/buttons/ghost_button.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/features/app/presentation/widgets/hermes_app_bar.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
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

  /// Show leave session confirmation dialog
  Future<void> _showLeaveSessionDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HermesSpacing.md),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.exit_to_app_rounded,
                  color: Theme.of(context).colorScheme.error,
                  size: 24,
                ),
                const SizedBox(width: HermesSpacing.sm),
                const Text('Leave Session'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to leave this session?',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: HermesSpacing.md),
                const Text('You will:'),
                const SizedBox(height: HermesSpacing.xs),
                const Text('• Stop receiving live translations'),
                const Text('• Be disconnected from the speaker'),
                const Text('• Need a new session code to rejoin'),
                const SizedBox(height: HermesSpacing.md),
                Container(
                  padding: const EdgeInsets.all(HermesSpacing.sm),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primaryContainer.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(HermesSpacing.sm),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: HermesSpacing.xs),
                      Expanded(
                        child: Text(
                          'The session will continue for other listeners.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w500,
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
              GhostButton(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(false),
              ),
              GhostButton(
                label: 'Leave Session',
                isDestructive: true,
                onPressed: () => Navigator.of(context).pop(true),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      await _leaveSession();
    }
  }

  /// Show connection info dialog
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
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoSection('Session Details', [
                    _buildDetailRow(
                      'Session Code',
                      sessionService.currentSession?.sessionId ?? 'Unknown',
                    ),
                    _buildDetailRow(
                      'Translation Language',
                      _targetLanguageName,
                    ),
                    _buildDetailRow('Status', _getStatusText(state.status)),
                  ]),

                  const SizedBox(height: HermesSpacing.lg),

                  _buildInfoSection('Translation Info', [
                    _buildDetailRow(
                      'Total Listeners',
                      '${state.audienceCount}',
                    ),
                    if (state.languageDistribution.isNotEmpty)
                      _buildDetailRow(
                        'Active Languages',
                        state.languageDistribution.keys.join(', '),
                      ),
                    if (state.lastTranslation != null)
                      _buildDetailRow(
                        'Last Translation',
                        '"${_truncateText(state.lastTranslation!, 50)}"',
                      ),
                  ]),
                ],
              ),
              actions: [
                GhostButton(
                  label: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
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
            width: 90,
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
