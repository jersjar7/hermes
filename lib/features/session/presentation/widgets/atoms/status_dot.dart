// lib/features/session/presentation/widgets/atoms/status_dot.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';

/// A small colored dot that indicates the current session status.
/// Perfect for compact status displays in headers or lists.
class StatusDot extends StatelessWidget {
  final HermesStatus status;
  final double size;

  const StatusDot({super.key, required this.status, this.size = 12.0});

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: HermesSpacing.xs,
            spreadRadius: 1,
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(BuildContext context) {
    final theme = Theme.of(context);

    switch (status) {
      case HermesStatus.idle:
        return theme.colorScheme.outline;
      case HermesStatus.listening:
        return theme.colorScheme.primary;
      case HermesStatus.translating:
        return Colors.amber;
      case HermesStatus.buffering:
        return Colors.orange;
      case HermesStatus.countdown:
        return Colors.blue;
      case HermesStatus.speaking:
        return Colors.green;
      case HermesStatus.paused:
        return theme.colorScheme.outline;
      case HermesStatus.error:
        return theme.colorScheme.error;
    }
  }
}
