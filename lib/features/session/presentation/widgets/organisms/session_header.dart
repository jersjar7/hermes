// lib/features/session/presentation/widgets/organisms/session_header.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/features/session/providers/connection_state_provider.dart';
import '../molecules/connection_status.dart';
import '../molecules/session_code_display.dart';
import '../atoms/status_dot.dart';

/// Main header showing session info, status, and connection state.
/// Used across all session pages for consistent status display.
class SessionHeader extends ConsumerWidget {
  final String? sessionCode;
  final bool showSessionCode;

  const SessionHeader({
    super.key,
    this.sessionCode,
    this.showSessionCode = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final sessionState = ref.watch(hermesControllerProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: sessionState.when(
        data:
            (state) => Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Status and connection
                    Row(
                      children: [
                        StatusDot(status: state.status),
                        const SizedBox(width: HermesSpacing.sm),
                        Text(
                          _getStatusText(state.status),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),

                    // Real connection status
                    Consumer(
                      builder: (context, ref, _) {
                        final connectionStatus = ref.watch(
                          connectionStatusProvider,
                        );
                        return ConnectionStatus(
                          isConnected: connectionStatus.connected,
                          isConnecting: connectionStatus.connecting,
                          customMessage: connectionStatus.message,
                          showText: false,
                        );
                      },
                    ),
                  ],
                ),

                if (showSessionCode && sessionCode != null) ...[
                  const SizedBox(height: HermesSpacing.md),
                  Column(
                    children: [
                      Text(
                        'Session Code',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                      const SizedBox(height: HermesSpacing.xs),
                      SessionCodeDisplay(code: sessionCode!),
                    ],
                  ),
                ],
              ],
            ),
        loading: () => const _HeaderSkeleton(),
        error: (error, _) => _HeaderError(error: error),
      ),
    );
  }

  String _getStatusText(HermesStatus status) {
    switch (status) {
      case HermesStatus.idle:
        return 'Ready';
      case HermesStatus.listening:
        return 'Listening';
      case HermesStatus.translating:
        return 'Translating';
      case HermesStatus.buffering:
        return 'Buffering';
      case HermesStatus.countdown:
        return 'Starting Soon';
      case HermesStatus.speaking:
        return 'Speaking';
      case HermesStatus.paused:
        return 'Paused';
      case HermesStatus.error:
        return 'Error';
    }
  }
}

class _HeaderSkeleton extends StatelessWidget {
  const _HeaderSkeleton();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          width: 120,
          height: 20,
          decoration: BoxDecoration(
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        Icon(HermesIcons.buffering, color: theme.colorScheme.outline),
      ],
    );
  }
}

class _HeaderError extends StatelessWidget {
  final Object error;

  const _HeaderError({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
        const SizedBox(width: HermesSpacing.xs),
        Text(
          'Session Error',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ],
    );
  }
}
