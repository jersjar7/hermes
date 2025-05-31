// lib/features/session/presentation/widgets/organisms/speaker_control_panel.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/core/presentation/widgets/buttons/primary_button.dart';
import 'package:hermes/core/presentation/widgets/cards/elevated_card.dart';
import '../molecules/waveform_display.dart';
import '../molecules/countdown_widget.dart';
import '../organisms/recent_transcript_display.dart';

/// Simplified control panel for speakers focused on mic controls and speech feedback.
/// No longer shows translations - only transcripts and speaking status.
class SpeakerControlPanel extends ConsumerStatefulWidget {
  final String languageCode;

  const SpeakerControlPanel({super.key, required this.languageCode});

  @override
  ConsumerState<SpeakerControlPanel> createState() =>
      _SpeakerControlPanelState();
}

class _SpeakerControlPanelState extends ConsumerState<SpeakerControlPanel> {
  final List<TranscriptEntry> _transcriptHistory = [];

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(hermesControllerProvider);

    return sessionState.when(
      data: (state) {
        // Update transcript history when new final transcripts arrive
        _updateTranscriptHistory(state);

        return Column(
          children: [
            // Main control card
            ElevatedCard(
              padding: const EdgeInsets.all(HermesSpacing.lg),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Status display area
                  _buildStatusArea(context, state),

                  const SizedBox(height: HermesSpacing.lg),

                  // Control button
                  _buildControlButton(context, ref, state),

                  // Real-time transcript display (only during listening)
                  if (state.status == HermesStatus.listening &&
                      state.lastTranscript != null &&
                      state.lastTranscript!.isNotEmpty) ...[
                    const SizedBox(height: HermesSpacing.md),
                    _buildRealTimeTranscript(context, state.lastTranscript!),
                  ],
                ],
              ),
            ),

            const SizedBox(height: HermesSpacing.md),

            // Recent transcript history
            if (_transcriptHistory.isNotEmpty)
              RecentTranscriptDisplay(
                entries: _transcriptHistory,
                recentCount: 3,
                autoScroll: true,
                onClear: () => setState(() => _transcriptHistory.clear()),
              ),
          ],
        );
      },
      loading: () => const _ControlPanelSkeleton(),
      error: (error, _) => _ControlPanelError(error: error),
    );
  }

  Widget _buildStatusArea(BuildContext context, state) {
    final theme = Theme.of(context);

    switch (state.status) {
      case HermesStatus.listening:
        return Column(
          children: [
            Text(
              'Listening...',
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: HermesSpacing.sm),
            Text(
              'Speak clearly into your microphone',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: HermesSpacing.md),
            const WaveformDisplay(isActive: true),
          ],
        );

      case HermesStatus.translating:
        return Column(
          children: [
            Icon(HermesIcons.translating, size: 48, color: Colors.amber),
            const SizedBox(height: HermesSpacing.sm),
            Text(
              'Sending to audience...',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.amber),
            ),
            const SizedBox(height: HermesSpacing.xs),
            Text(
              'Processing your speech',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        );

      case HermesStatus.countdown:
        return Column(
          children: [
            Text('Starting in', style: theme.textTheme.titleMedium),
            const SizedBox(height: HermesSpacing.sm),
            CountdownWidget(seconds: state.countdownSeconds ?? 0, size: 100),
          ],
        );

      case HermesStatus.buffering:
        return Column(
          children: [
            const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(height: HermesSpacing.sm),
            Text(
              'Ready to listen',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: HermesSpacing.xs),
            Text(
              'Start speaking when ready',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        );

      case HermesStatus.paused:
        return Column(
          children: [
            Icon(HermesIcons.pause, size: 48, color: theme.colorScheme.outline),
            const SizedBox(height: HermesSpacing.sm),
            Text(
              'Session Paused',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: HermesSpacing.xs),
            Text(
              'Tap Resume to continue',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        );

      case HermesStatus.error:
        return Column(
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: HermesSpacing.sm),
            Text(
              'Session Error',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: HermesSpacing.xs),
              Text(
                state.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.error,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );

      default:
        return Column(
          children: [
            Icon(
              HermesIcons.microphone,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: HermesSpacing.sm),
            Text('Ready to start', style: theme.textTheme.titleMedium),
            const SizedBox(height: HermesSpacing.xs),
            Text(
              'Tap the button below to begin speaking',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        );
    }
  }

  Widget _buildControlButton(BuildContext context, WidgetRef ref, state) {
    final isSessionActive =
        state.status == HermesStatus.listening ||
        state.status == HermesStatus.translating ||
        state.status == HermesStatus.countdown ||
        state.status == HermesStatus.paused;

    final isProcessing =
        state.status == HermesStatus.buffering ||
        state.status == HermesStatus.translating;

    return Column(
      children: [
        PrimaryButton(
          label: isSessionActive ? 'Stop Session' : 'Start Speaking',
          icon: isSessionActive ? HermesIcons.stop : HermesIcons.microphone,
          isFullWidth: true,
          isLoading: isProcessing,
          onPressed:
              isProcessing
                  ? null
                  : () => _handleControlTap(ref, isSessionActive),
        ),

        // Show pause/resume buttons when session is active
        if (isSessionActive && !isProcessing) ...[
          const SizedBox(height: HermesSpacing.sm),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      state.status == HermesStatus.listening
                          ? () => _handlePause(ref)
                          : state.status == HermesStatus.paused
                          ? () => _handleResume(ref)
                          : null,
                  icon: Icon(
                    state.status == HermesStatus.listening
                        ? HermesIcons.pause
                        : HermesIcons.play,
                    size: 18,
                  ),
                  label: Text(
                    state.status == HermesStatus.listening ? 'Pause' : 'Resume',
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildRealTimeTranscript(BuildContext context, String transcript) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(HermesSpacing.sm),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.5),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.mic_rounded,
                size: 16,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: HermesSpacing.xs),
              Text(
                'You\'re saying:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              // Live indicator
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          ),
          const SizedBox(height: HermesSpacing.xs),
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 100),
            child: SingleChildScrollView(
              child: Text(
                transcript,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _updateTranscriptHistory(state) {
    // Add final transcripts to history (avoid duplicates)
    if (state.lastTranscript != null &&
        state.lastTranscript!.isNotEmpty &&
        state.status != HermesStatus.listening && // Only add when finalized
        (_transcriptHistory.isEmpty ||
            _transcriptHistory.last.text != state.lastTranscript)) {
      setState(() {
        _transcriptHistory.add(
          TranscriptEntry(
            text: state.lastTranscript!,
            timestamp: DateTime.now(),
            isFinal: true,
          ),
        );

        // Keep only last 20 entries to avoid memory issues
        if (_transcriptHistory.length > 20) {
          _transcriptHistory.removeAt(0);
        }
      });
    }
  }

  void _handleControlTap(WidgetRef ref, bool isActive) {
    if (isActive) {
      ref.read(hermesControllerProvider.notifier).stop();
    } else {
      ref
          .read(hermesControllerProvider.notifier)
          .startSession(widget.languageCode);
    }
  }

  void _handlePause(WidgetRef ref) async {
    try {
      await ref.read(hermesControllerProvider.notifier).pauseSession();
    } catch (e) {
      print('❌ [SpeakerControlPanel] Failed to pause session: $e');
    }
  }

  void _handleResume(WidgetRef ref) async {
    try {
      await ref.read(hermesControllerProvider.notifier).resumeSession();
    } catch (e) {
      print('❌ [SpeakerControlPanel] Failed to resume session: $e');
    }
  }
}

class _ControlPanelSkeleton extends StatelessWidget {
  const _ControlPanelSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(height: HermesSpacing.lg),
        Container(
          width: double.infinity,
          height: 48,
          decoration: BoxDecoration(
            color: Colors.grey.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ],
    );
  }
}

class _ControlPanelError extends StatelessWidget {
  final Object error;

  const _ControlPanelError({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
        const SizedBox(height: HermesSpacing.sm),
        Text(
          'Control Error',
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        const SizedBox(height: HermesSpacing.xs),
        Text(
          'Please try restarting the session',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }
}
