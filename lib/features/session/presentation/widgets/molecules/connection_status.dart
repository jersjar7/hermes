// lib/features/session/presentation/widgets/molecules/connection_status.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import '../atoms/connection_indicator.dart';

/// Shows connection status with icon and descriptive text.
/// Used in headers and status bars to inform users of connectivity.
class ConnectionStatus extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final String? customMessage;
  final bool showText;

  const ConnectionStatus({
    super.key,
    required this.isConnected,
    this.isConnecting = false,
    this.customMessage,
    this.showText = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ConnectionIndicator(
          isConnected: isConnected,
          isConnecting: isConnecting,
        ),
        if (showText) ...[
          const SizedBox(width: HermesSpacing.xs),
          Text(
            customMessage ?? _getStatusText(),
            style: theme.textTheme.bodySmall?.copyWith(
              color: _getTextColor(theme),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  String _getStatusText() {
    if (customMessage != null) return customMessage!;
    if (isConnecting) return 'Connecting...';
    return isConnected ? 'Connected' : 'Disconnected';
  }

  Color _getTextColor(ThemeData theme) {
    if (isConnecting) return Colors.amber;
    return isConnected ? Colors.green : theme.colorScheme.error;
  }
}
