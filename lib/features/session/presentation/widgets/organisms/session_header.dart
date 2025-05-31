// lib/features/session/presentation/widgets/organisms/session_header.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';
import '../atoms/status_dot.dart';

/// Simplified session header focused on high-level status information.
/// Works in coordination with SessionStatusBar to avoid information duplication.
/// Shows session branding, overall status, and role-specific information.
class SessionHeader extends ConsumerWidget {
  final bool showMinimal;
  final String? customTitle;

  const SessionHeader({super.key, this.showMinimal = false, this.customTitle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessionState = ref.watch(hermesControllerProvider);
    final sessionService = getIt<ISessionService>();

    return sessionState.when(
      data:
          (state) => Container(
            width: double.infinity,
            padding: EdgeInsets.all(
              showMinimal ? HermesSpacing.sm : HermesSpacing.md,
            ),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              border: Border(
                bottom: BorderSide(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
            ),
            child:
                showMinimal
                    ? _buildMinimalHeader(context, theme, state, sessionService)
                    : _buildFullHeader(context, theme, state, sessionService),
          ),
      loading: () => _buildHeaderSkeleton(context),
      error: (error, _) => _buildHeaderError(context, error),
    );
  }

  Widget _buildFullHeader(
    BuildContext context,
    ThemeData theme,
    state,
    ISessionService sessionService,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title and role indicator
        Row(
          children: [
            Icon(
              HermesIcons.translating,
              size: 24,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: HermesSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    customTitle ?? 'Hermes Session',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    sessionService.isSpeaker
                        ? 'Speaker Mode'
                        : 'Listening Mode',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            // Status indicator
            _buildStatusIndicator(context, theme, state),
          ],
        ),

        // Status description (only if not idle)
        if (state.status != HermesStatus.idle) ...[
          const SizedBox(height: HermesSpacing.sm),
          _buildStatusDescription(context, theme, state, sessionService),
        ],
      ],
    );
  }

  Widget _buildMinimalHeader(
    BuildContext context,
    ThemeData theme,
    state,
    ISessionService sessionService,
  ) {
    return Row(
      children: [
        StatusDot(status: state.status, size: 10),
        const SizedBox(width: HermesSpacing.sm),
        Expanded(
          child: Text(
            _getMinimalStatusText(state.status, sessionService.isSpeaker),
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatusIndicator(BuildContext context, ThemeData theme, state) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HermesSpacing.sm,
        vertical: HermesSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: _getStatusBackgroundColor(theme, state.status),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          StatusDot(status: state.status, size: 8),
          const SizedBox(width: HermesSpacing.xs),
          Text(
            _getStatusText(state.status),
            style: theme.textTheme.labelSmall?.copyWith(
              color: _getStatusTextColor(theme, state.status),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusDescription(
    BuildContext context,
    ThemeData theme,
    state,
    ISessionService sessionService,
  ) {
    final description = _getStatusDescription(
      state.status,
      sessionService.isSpeaker,
    );
    if (description.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(HermesSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(HermesSpacing.sm),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(state.status),
            size: 16,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: HermesSpacing.sm),
          Expanded(
            child: Text(
              description,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSkeleton(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: HermesSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 150,
                  height: 20,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: HermesSpacing.xs),
                Container(
                  width: 100,
                  height: 14,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderError(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: HermesSpacing.sm),
          Text(
            'Session Error',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for status styling and text
  Color _getStatusBackgroundColor(ThemeData theme, HermesStatus status) {
    switch (status) {
      case HermesStatus.listening:
        return theme.colorScheme.primary.withValues(alpha: 0.1);
      case HermesStatus.translating:
        return Colors.amber.withValues(alpha: 0.1);
      case HermesStatus.speaking:
        return Colors.green.withValues(alpha: 0.1);
      case HermesStatus.error:
        return theme.colorScheme.error.withValues(alpha: 0.1);
      default:
        return theme.colorScheme.outline.withValues(alpha: 0.1);
    }
  }

  Color _getStatusTextColor(ThemeData theme, HermesStatus status) {
    switch (status) {
      case HermesStatus.listening:
        return theme.colorScheme.primary;
      case HermesStatus.translating:
        return Colors.amber.shade700;
      case HermesStatus.speaking:
        return Colors.green.shade700;
      case HermesStatus.error:
        return theme.colorScheme.error;
      default:
        return theme.colorScheme.outline;
    }
  }

  String _getStatusText(HermesStatus status) {
    switch (status) {
      case HermesStatus.idle:
        return 'Ready';
      case HermesStatus.listening:
        return 'Live';
      case HermesStatus.translating:
        return 'Processing';
      case HermesStatus.buffering:
        return 'Ready'; // Changed from 'Buffering'
      case HermesStatus.countdown:
        return 'Starting';
      case HermesStatus.speaking:
        return 'Playing';
      case HermesStatus.paused:
        return 'Paused';
      case HermesStatus.error:
        return 'Error';
    }
  }

  String _getMinimalStatusText(HermesStatus status, bool isSpeaker) {
    switch (status) {
      case HermesStatus.idle:
        return 'Ready to start';
      case HermesStatus.listening:
        return isSpeaker ? 'Speaking live' : 'Listening live';
      case HermesStatus.translating:
        return 'Processing speech';
      case HermesStatus.buffering:
        return isSpeaker ? 'Ready for your speech' : 'Preparing session';
      case HermesStatus.countdown:
        return 'Starting soon';
      case HermesStatus.speaking:
        return 'Playing translation';
      case HermesStatus.paused:
        return 'Session paused';
      case HermesStatus.error:
        return 'Session error';
    }
  }

  String _getStatusDescription(HermesStatus status, bool isSpeaker) {
    switch (status) {
      case HermesStatus.listening:
        return isSpeaker
            ? 'Your speech is being captured and sent to the audience'
            : 'Listening for translations from the speaker';
      case HermesStatus.translating:
        return isSpeaker
            ? 'Your speech is being processed for translation'
            : 'Speaker\'s words are being translated';
      case HermesStatus.buffering:
        return isSpeaker
            ? 'Ready to listen - start speaking when you\'re ready'
            : 'Waiting for the session to begin';
      case HermesStatus.countdown:
        return 'Session will begin shortly';
      case HermesStatus.speaking:
        return isSpeaker
            ? 'Translation is being played to the audience'
            : 'Playing translated speech';
      case HermesStatus.paused:
        return 'Session is temporarily paused';
      case HermesStatus.error:
        return 'An error occurred during the session';
      default:
        return '';
    }
  }

  IconData _getStatusIcon(HermesStatus status) {
    switch (status) {
      case HermesStatus.listening:
        return HermesIcons.listening;
      case HermesStatus.translating:
        return HermesIcons.translating;
      case HermesStatus.buffering:
        return HermesIcons.buffering;
      case HermesStatus.countdown:
        return Icons.schedule_rounded;
      case HermesStatus.speaking:
        return HermesIcons.speaker;
      case HermesStatus.paused:
        return HermesIcons.pause;
      case HermesStatus.error:
        return Icons.error_outline;
      default:
        return Icons.info_outline;
    }
  }
}
