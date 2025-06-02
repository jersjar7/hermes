// lib/features/session/presentation/widgets/organisms/speaker_control_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/core/presentation/widgets/cards/elevated_card.dart';
import '../molecules/waveform_display.dart';
import '../molecules/countdown_widget.dart';

/// Compact speaker control panel focused ONLY on speaking controls and status.
/// Transcript display is now handled by the separate TranscriptChatBox component.
class SpeakerControlPanel extends ConsumerWidget {
  final String languageCode;
  final bool isCompact;

  const SpeakerControlPanel({
    super.key,
    required this.languageCode,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(hermesControllerProvider);

    return sessionState.when(
      data:
          (state) => ElevatedCard(
            padding: EdgeInsets.all(
              isCompact ? HermesSpacing.md : HermesSpacing.lg,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status display area (more compact)
                _buildCompactStatusArea(context, state),

                if (!isCompact) const SizedBox(height: HermesSpacing.lg),
                if (isCompact) const SizedBox(height: HermesSpacing.md),

                // Speaking control buttons
                _buildSpeakingControls(context, ref, state),
              ],
            ),
          ),
      loading: () => const _ControlPanelSkeleton(),
      error: (error, _) => _ControlPanelError(error: error),
    );
  }

  Widget _buildCompactStatusArea(BuildContext context, state) {
    final theme = Theme.of(context);

    switch (state.status) {
      case HermesStatus.listening:
        return Row(
          children: [
            // Live indicator
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: HermesSpacing.sm),

            // Status text and waveform
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Speaking Live',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(height: HermesSpacing.xs),
                    Text(
                      'Your speech is being translated for the audience',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Compact waveform
            const CompactWaveformDisplay(isActive: true),
          ],
        );

      case HermesStatus.translating:
        return Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.amber),
              ),
            ),
            const SizedBox(width: HermesSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Processing Speech',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(height: HermesSpacing.xs),
                    Text(
                      'Sending translation to audience...',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(HermesIcons.translating, color: Colors.amber, size: 24),
          ],
        );

      case HermesStatus.countdown:
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CountdownWidget(seconds: state.countdownSeconds ?? 0, size: 60),
            const SizedBox(width: HermesSpacing.md),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Starting in',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Get ready to speak',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ],
        );

      case HermesStatus.buffering:
        return Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
              ),
            ),
            const SizedBox(width: HermesSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Starting Session',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(height: HermesSpacing.xs),
                    Text(
                      'Initializing microphone and translation services',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              HermesIcons.microphone,
              color: theme.colorScheme.primary,
              size: 24,
            ),
          ],
        );

      case HermesStatus.paused:
        return Row(
          children: [
            Icon(HermesIcons.pause, color: Colors.amber, size: 20),
            const SizedBox(width: HermesSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Speaking Paused',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.amber,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(height: HermesSpacing.xs),
                    Text(
                      'Session is active but your microphone is muted',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );

      case HermesStatus.error:
        return Row(
          children: [
            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
            const SizedBox(width: HermesSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Speaking Error',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.error,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isCompact && state.errorMessage != null) ...[
                    const SizedBox(height: HermesSpacing.xs),
                    Text(
                      state.errorMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
          ],
        );

      default:
        return Row(
          children: [
            Icon(
              HermesIcons.microphone,
              color: theme.colorScheme.outline,
              size: 20,
            ),
            const SizedBox(width: HermesSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session Ready',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (!isCompact) ...[
                    const SizedBox(height: HermesSpacing.xs),
                    Text(
                      'Session will begin automatically when started',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
    }
  }

  /// Compact speaking controls focused on pause/resume
  Widget _buildSpeakingControls(BuildContext context, WidgetRef ref, state) {
    final isSpeaking =
        state.status == HermesStatus.listening ||
        state.status == HermesStatus.translating;
    final isPaused = state.status == HermesStatus.paused;
    final isProcessing =
        state.status == HermesStatus.buffering ||
        state.status == HermesStatus.translating;

    // Show different controls based on state
    if (isSpeaking) {
      return _buildPauseButton(context, ref, isProcessing);
    } else if (isPaused) {
      return _buildResumeButton(context, ref);
    } else if (state.status == HermesStatus.buffering ||
        state.status == HermesStatus.countdown) {
      return _buildStartingIndicator(context);
    } else {
      return _buildReadyIndicator(context);
    }
  }

  Widget _buildPauseButton(
    BuildContext context,
    WidgetRef ref,
    bool isProcessing,
  ) {
    return SizedBox(
      width: double.infinity,
      height: isCompact ? 40 : 48,
      child: OutlinedButton.icon(
        onPressed: isProcessing ? null : () => _handlePauseSpeaking(ref),
        icon:
            isProcessing
                ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.amber),
                  ),
                )
                : Icon(HermesIcons.pause, size: 18),
        label: Text(
          isProcessing ? 'Processing...' : 'Pause Speaking',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isCompact ? 14 : 16,
          ),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.amber.shade700,
          side: BorderSide(color: Colors.amber.shade400, width: 2),
          backgroundColor: Colors.amber.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  /// Builds a prominent resume button (green/primary)
  Widget _buildResumeButton(BuildContext context, WidgetRef ref) {
    return SizedBox(
      width: double.infinity,
      height: isCompact ? 40 : 48,
      child: ElevatedButton.icon(
        onPressed: () => _handleResumeSpeaking(ref),
        icon: Icon(HermesIcons.microphone, size: 18),
        label: Text(
          'Resume Speaking',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: isCompact ? 14 : 16,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.green,
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: Colors.green.withValues(alpha: 0.3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }

  Widget _buildStartingIndicator(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      height: isCompact ? 40 : 48,
      padding: const EdgeInsets.symmetric(horizontal: HermesSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
            ),
          ),
          const SizedBox(width: HermesSpacing.sm),
          Text(
            'Session Starting',
            style: TextStyle(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: isCompact ? 14 : 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReadyIndicator(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      height: isCompact ? 40 : 48,
      padding: const EdgeInsets.symmetric(horizontal: HermesSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            HermesIcons.microphone,
            color: theme.colorScheme.outline,
            size: 18,
          ),
          const SizedBox(width: HermesSpacing.sm),
          Text(
            'Ready to Start',
            style: TextStyle(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w600,
              fontSize: isCompact ? 14 : 16,
            ),
          ),
        ],
      ),
    );
  }

  void _handlePauseSpeaking(WidgetRef ref) async {
    try {
      await ref.read(hermesControllerProvider.notifier).pauseSession();
    } catch (e) {
      print('❌ [SpeakerControlPanel] Failed to pause speaking: $e');
    }
  }

  void _handleResumeSpeaking(WidgetRef ref) async {
    try {
      await ref.read(hermesControllerProvider.notifier).resumeSession();
    } catch (e) {
      print('❌ [SpeakerControlPanel] Failed to resume speaking: $e');
    }
  }
}

class _ControlPanelSkeleton extends StatelessWidget {
  const _ControlPanelSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  color: theme.colorScheme.outline.withValues(alpha: 0.3),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: HermesSpacing.sm),
              Expanded(
                child: Container(
                  height: 20,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.outline.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: HermesSpacing.md),
          Container(
            width: double.infinity,
            height: 40,
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ],
      ),
    );
  }
}

class _ControlPanelError extends StatelessWidget {
  final Object error;

  const _ControlPanelError({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, size: 32, color: theme.colorScheme.error),
          const SizedBox(height: HermesSpacing.sm),
          Text(
            'Speaking Control Error',
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: HermesSpacing.xs),
          Text(
            'Please check your microphone and try again',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
