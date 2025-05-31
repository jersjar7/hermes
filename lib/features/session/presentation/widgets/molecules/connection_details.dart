// lib/features/session/presentation/widgets/molecules/connection_details.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/features/session/providers/connection_state_provider.dart';
import '../atoms/connection_indicator.dart';

/// Detailed connection information showing network type, socket status, etc.
/// Useful for debugging and settings pages.
class ConnectionDetails extends ConsumerWidget {
  final bool showTechnicalDetails;

  const ConnectionDetails({super.key, this.showTechnicalDetails = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionAsync = ref.watch(connectionStateProvider);
    final theme = Theme.of(context);

    return connectionAsync.when(
      data:
          (state) => Container(
            padding: const EdgeInsets.all(HermesSpacing.md),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(HermesSpacing.sm),
              border: Border.all(
                color: _getBorderColor(theme, state),
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Main status row
                Row(
                  children: [
                    ConnectionIndicator(
                      isConnected: state.isFullyConnected,
                      isConnecting: state.isConnecting,
                      size: 24,
                    ),
                    const SizedBox(width: HermesSpacing.sm),
                    Expanded(
                      child: Text(
                        state.statusMessage,
                        style: theme.textTheme.titleMedium?.copyWith(
                          color: _getStatusColor(theme, state),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),

                if (showTechnicalDetails) ...[
                  const SizedBox(height: HermesSpacing.md),

                  // Technical details
                  _DetailRow(
                    icon: HermesIcons.connected,
                    label: 'Network',
                    value: state.isNetworkOnline ? 'Online' : 'Offline',
                    valueColor:
                        state.isNetworkOnline
                            ? Colors.green
                            : theme.colorScheme.error,
                  ),

                  _DetailRow(
                    icon: Icons.wifi_rounded,
                    label: 'Connection Type',
                    value: state.connectionType.toUpperCase(),
                    valueColor: theme.colorScheme.onSurface,
                  ),

                  _DetailRow(
                    icon: Icons.cable_rounded,
                    label: 'WebSocket',
                    value:
                        state.isSocketConnected ? 'Connected' : 'Disconnected',
                    valueColor:
                        state.isSocketConnected
                            ? Colors.green
                            : theme.colorScheme.error,
                  ),

                  if (state.error != null)
                    _DetailRow(
                      icon: Icons.error_outline,
                      label: 'Error',
                      value: state.error!,
                      valueColor: theme.colorScheme.error,
                    ),
                ],
              ],
            ),
          ),
      loading: () => _buildLoadingState(context),
      error: (error, _) => _buildErrorState(context, error),
    );
  }

  Color _getBorderColor(ThemeData theme, HermesConnectionState state) {
    if (state.error != null) return theme.colorScheme.error;
    if (state.isFullyConnected) return Colors.green;
    if (state.isConnecting) return Colors.amber;
    return theme.colorScheme.error;
  }

  Color _getStatusColor(ThemeData theme, HermesConnectionState state) {
    if (state.error != null) return theme.colorScheme.error;
    if (state.isFullyConnected) return Colors.green;
    if (state.isConnecting) return Colors.amber;
    return theme.colorScheme.error;
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      child: const Row(
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(width: HermesSpacing.sm),
          Text('Checking connection...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: HermesSpacing.sm),
          Text(
            'Connection check failed',
            style: TextStyle(color: theme.colorScheme.error),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  const _DetailRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(top: HermesSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: HermesSpacing.sm),
          Text(
            '$label:',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: HermesSpacing.xs),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              color: valueColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
