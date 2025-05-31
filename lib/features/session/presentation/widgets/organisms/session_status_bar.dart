// lib/features/session/presentation/widgets/organisms/session_status_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/features/session/providers/connection_state_provider.dart';
import '../molecules/audience_info.dart';
import '../atoms/connection_indicator.dart';

/// Compact status bar showing essential session information.
/// Designed for minimal distraction during active speaking.
class SessionStatusBar extends ConsumerStatefulWidget {
  final String sessionCode;
  final Duration sessionDuration;
  final int audienceCount;
  final Map<String, int> languageDistribution;
  final VoidCallback? onSessionCodeTap;

  const SessionStatusBar({
    super.key,
    required this.sessionCode,
    required this.sessionDuration,
    this.audienceCount = 0,
    this.languageDistribution = const {},
    this.onSessionCodeTap,
  });

  @override
  ConsumerState<SessionStatusBar> createState() => _SessionStatusBarState();
}

class _SessionStatusBarState extends ConsumerState<SessionStatusBar> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isConnected = ref.watch(isConnectedProvider);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HermesSpacing.md,
        vertical: HermesSpacing.sm,
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
      child: Row(
        children: [
          // Session code (tappable)
          _buildSessionCode(context),

          const SizedBox(width: HermesSpacing.md),

          // Duration
          _buildDuration(context),

          const Spacer(),

          // Audience info
          if (widget.audienceCount > 0) ...[
            Flexible(
              child: AudienceInfo(
                totalListeners: widget.audienceCount,
                languageDistribution: widget.languageDistribution,
                showIcon: true,
                textStyle: theme.textTheme.bodySmall,
              ),
            ),
            const SizedBox(width: HermesSpacing.md),
          ],

          // Connection indicator
          ConnectionIndicator(isConnected: isConnected, size: 16),
        ],
      ),
    );
  }

  Widget _buildSessionCode(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: widget.onSessionCodeTap,
      borderRadius: BorderRadius.circular(HermesSpacing.xs),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HermesSpacing.sm,
          vertical: HermesSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(HermesSpacing.xs),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.sessionCode,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            if (widget.onSessionCodeTap != null) ...[
              const SizedBox(width: HermesSpacing.xs),
              Icon(
                HermesIcons.copy,
                size: 12,
                color: theme.colorScheme.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDuration(BuildContext context) {
    final theme = Theme.of(context);
    final formatted = _formatDuration(widget.sessionDuration);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.timer_outlined, size: 14, color: theme.colorScheme.outline),
        const SizedBox(width: HermesSpacing.xs),
        Text(
          formatted,
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }
}

/// Minimal version for very compact spaces
class MinimalSessionStatusBar extends StatelessWidget {
  final String sessionCode;
  final bool isConnected;
  final VoidCallback? onTap;

  const MinimalSessionStatusBar({
    super.key,
    required this.sessionCode,
    required this.isConnected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(HermesSpacing.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              sessionCode,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: HermesSpacing.sm),
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isConnected ? Colors.green : theme.colorScheme.error,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
