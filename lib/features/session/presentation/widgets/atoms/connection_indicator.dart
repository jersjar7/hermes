// lib/features/session/presentation/widgets/atoms/connection_indicator.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/core/presentation/widgets/animations/pulse_animation.dart';

/// Shows connection status with appropriate icon and animation.
/// Pulses when connecting, static when connected/disconnected.
class ConnectionIndicator extends StatelessWidget {
  final bool isConnected;
  final bool isConnecting;
  final double size;

  const ConnectionIndicator({
    super.key,
    required this.isConnected,
    this.isConnecting = false,
    this.size = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final icon = Icon(_getIcon(), size: size, color: _getColor(theme));

    if (isConnecting) {
      return PulseAnimation(child: icon);
    }

    return icon;
  }

  IconData _getIcon() {
    if (isConnecting) return HermesIcons.buffering;
    return isConnected ? HermesIcons.connected : HermesIcons.disconnected;
  }

  Color _getColor(ThemeData theme) {
    if (isConnecting) return Colors.amber;
    return isConnected ? Colors.green : theme.colorScheme.error;
  }
}
