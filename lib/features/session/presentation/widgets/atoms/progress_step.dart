// lib/features/session/presentation/widgets/atoms/progress_step.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';

/// An atom for displaying individual progress steps with status indicators.
/// Used in loading overlays and multi-step processes.
class ProgressStep extends StatelessWidget {
  final String text;
  final ProgressStepStatus status;
  final double indicatorSize;

  const ProgressStep({
    super.key,
    required this.text,
    required this.status,
    this.indicatorSize = 20.0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: HermesSpacing.xs),
      child: Row(
        children: [
          // Step indicator
          SizedBox(
            width: indicatorSize,
            height: indicatorSize,
            child: _buildIndicator(theme),
          ),

          const SizedBox(width: HermesSpacing.sm),

          // Step text
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: _getTextColor(theme),
                fontWeight: _getFontWeight(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIndicator(ThemeData theme) {
    switch (status) {
      case ProgressStepStatus.pending:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.outline.withValues(alpha: 0.3),
          ),
        );

      case ProgressStepStatus.current:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.primary,
          ),
          child: SizedBox(
            width: indicatorSize - 4,
            height: indicatorSize - 4,
            child: const Center(
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation(Colors.white),
              ),
            ),
          ),
        );

      case ProgressStepStatus.completed:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.green,
          ),
          child: Icon(
            Icons.check,
            size: indicatorSize * 0.6,
            color: Colors.white,
          ),
        );

      case ProgressStepStatus.error:
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: theme.colorScheme.error,
          ),
          child: Icon(
            Icons.close,
            size: indicatorSize * 0.6,
            color: Colors.white,
          ),
        );
    }
  }

  Color _getTextColor(ThemeData theme) {
    switch (status) {
      case ProgressStepStatus.pending:
        return theme.colorScheme.outline;
      case ProgressStepStatus.current:
      case ProgressStepStatus.completed:
        return theme.colorScheme.onSurface;
      case ProgressStepStatus.error:
        return theme.colorScheme.error;
    }
  }

  FontWeight _getFontWeight() {
    switch (status) {
      case ProgressStepStatus.pending:
        return FontWeight.normal;
      case ProgressStepStatus.current:
        return FontWeight.w600;
      case ProgressStepStatus.completed:
      case ProgressStepStatus.error:
        return FontWeight.w500;
    }
  }
}

/// Status of a progress step
enum ProgressStepStatus { pending, current, completed, error }

/// Compact version for smaller spaces
class CompactProgressStep extends StatelessWidget {
  final String text;
  final ProgressStepStatus status;

  const CompactProgressStep({
    super.key,
    required this.text,
    required this.status,
  });

  @override
  Widget build(BuildContext context) {
    return ProgressStep(text: text, status: status, indicatorSize: 16.0);
  }
}
