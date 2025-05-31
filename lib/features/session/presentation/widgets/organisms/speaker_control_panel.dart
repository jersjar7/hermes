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

/// Main control panel for speakers with mic controls, waveform, and status.
/// Central interaction area for starting/stopping sessions and monitoring activity.
class SpeakerControlPanel extends ConsumerWidget {
  final String languageCode;

  const SpeakerControlPanel({super.key, required this.languageCode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionState = ref.watch(hermesControllerProvider);

    return ElevatedCard(
      padding: const EdgeInsets.all(HermesSpacing.lg),
      child: sessionState.when(
        data:
            (state) => Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Status display area
                _buildStatusArea(context, state),

                const SizedBox(height: HermesSpacing.lg),

                // Control button
                _buildControlButton(context, ref, state),

                // Current transcript display
                if (state.lastTranscript != null &&
                    state.lastTranscript!.isNotEmpty) ...[
                  const SizedBox(height: HermesSpacing.md),
                  _buildCurrentTranscript(context, state.lastTranscript!),
                ],

                // Last completed transcript
                if (state.lastTranslation != null &&
                    state.lastTranslation!.isNotEmpty) ...[
                  const SizedBox(height: HermesSpacing.md),
                  _buildLastTranslation(context, state.lastTranslation!),
                ],
              ],
            ),
        loading: () => const _ControlPanelSkeleton(),
        error: (error, _) => _ControlPanelError(error: error),
      ),
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
              'Translating...',
              style: theme.textTheme.titleMedium?.copyWith(color: Colors.amber),
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
          ],
        );
    }
  }

  Widget _buildControlButton(BuildContext context, WidgetRef ref, state) {
    final isActive =
        state.status == HermesStatus.listening ||
        state.status == HermesStatus.translating;

    return PrimaryButton(
      label: isActive ? 'Stop Speaking' : 'Start Speaking',
      icon: isActive ? HermesIcons.stop : HermesIcons.microphone,
      isFullWidth: true,
      onPressed: () => _handleControlTap(ref, isActive),
    );
  }

  Widget _buildCurrentTranscript(BuildContext context, String transcript) {
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
            ],
          ),
          const SizedBox(height: HermesSpacing.xs),
          Text(
            transcript,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLastTranslation(BuildContext context, String translation) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(HermesSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(HermesIcons.translating, size: 16, color: Colors.green),
              const SizedBox(width: HermesSpacing.xs),
              Text(
                'Latest translation:',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: Colors.green,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: HermesSpacing.xs),
          Text(
            translation,
            style: theme.textTheme.bodyMedium?.copyWith(color: Colors.green),
          ),
        ],
      ),
    );
  }

  void _handleControlTap(WidgetRef ref, bool isActive) {
    if (isActive) {
      ref.read(hermesControllerProvider.notifier).stop();
    } else {
      ref.read(hermesControllerProvider.notifier).startSession(languageCode);
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
      ],
    );
  }
}
