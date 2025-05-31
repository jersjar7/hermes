// lib/features/session/presentation/widgets/molecules/transcript_bubble.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/widgets/animations/fade_in_widget.dart';

/// A speech bubble for displaying transcripts and translations.
/// Supports different types (original, translated) with distinct styling.
class TranscriptBubble extends StatelessWidget {
  final String text;
  final bool isTranslation;
  final bool isLoading;
  final DateTime? timestamp;

  const TranscriptBubble({
    super.key,
    required this.text,
    this.isTranslation = false,
    this.isLoading = false,
    this.timestamp,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FadeInWidget(
      slideFrom: const Offset(0, 0.3),
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(
          vertical: HermesSpacing.xs,
          horizontal: HermesSpacing.md,
        ),
        padding: const EdgeInsets.all(HermesSpacing.md),
        decoration: BoxDecoration(
          color: _getBackgroundColor(theme),
          borderRadius: BorderRadius.circular(HermesSpacing.md),
          border:
              isTranslation
                  ? Border.all(
                    color: theme.colorScheme.primary.withValues(alpha: 0.3),
                    width: 1,
                  )
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isLoading)
              const _LoadingDots()
            else
              Text(
                text,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: _getTextColor(theme),
                ),
              ),
            if (timestamp != null)
              Padding(
                padding: const EdgeInsets.only(top: HermesSpacing.xs),
                child: Text(
                  _formatTime(timestamp!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color _getBackgroundColor(ThemeData theme) {
    if (isTranslation) {
      return theme.colorScheme.primaryContainer.withValues(alpha: 0.1);
    }
    return theme.colorScheme.surfaceContainerHighest;
  }

  Color _getTextColor(ThemeData theme) {
    return isTranslation
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurface;
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }
}

class _LoadingDots extends StatefulWidget {
  const _LoadingDots();

  @override
  State<_LoadingDots> createState() => _LoadingDotsState();
}

class _LoadingDotsState extends State<_LoadingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 3; i++)
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final delay = i * 0.3;
              final value = (_controller.value - delay).clamp(0.0, 1.0);
              return Container(
                margin: const EdgeInsets.only(right: 4),
                child: Opacity(
                  opacity: (value * 2).clamp(0.3, 1.0),
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outline,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
