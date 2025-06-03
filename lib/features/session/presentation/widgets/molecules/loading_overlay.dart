// lib/features/session/presentation/widgets/molecules/loading_overlay.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/widgets/cards/elevated_card.dart';
import '../atoms/progress_step.dart';

/// A reusable loading overlay with title, message, and optional progress steps.
/// Used for session joining, going live, and other loading states.
class LoadingOverlay extends StatelessWidget {
  final String title;
  final String message;
  final List<LoadingStep>? steps;
  final Widget? customContent;
  final bool showProgress;

  const LoadingOverlay({
    super.key,
    required this.title,
    required this.message,
    this.steps,
    this.customContent,
    this.showProgress = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: Center(
        child: ElevatedCard(
          elevation: 8,
          margin: const EdgeInsets.all(HermesSpacing.lg),
          padding: const EdgeInsets.all(HermesSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Loading animation
              if (showProgress) ...[
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    strokeWidth: 4,
                    valueColor: AlwaysStoppedAnimation(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: HermesSpacing.lg),
              ],

              // Title
              Text(
                title,
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),

              const SizedBox(height: HermesSpacing.sm),

              // Message
              Text(
                message,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
                textAlign: TextAlign.center,
              ),

              // Progress steps
              if (steps != null && steps!.isNotEmpty) ...[
                const SizedBox(height: HermesSpacing.lg),
                _buildProgressSteps(steps!),
              ],

              // Custom content
              if (customContent != null) ...[
                const SizedBox(height: HermesSpacing.lg),
                customContent!,
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressSteps(List<LoadingStep> steps) {
    return Column(
      children:
          steps.map((step) {
            return ProgressStep(text: step.text, status: step.status);
          }).toList(),
    );
  }
}

/// Data model for loading steps
class LoadingStep {
  final String text;
  final ProgressStepStatus status;

  const LoadingStep({required this.text, required this.status});

  /// Creates a pending step
  LoadingStep.pending(this.text) : status = ProgressStepStatus.pending;

  /// Creates a current step
  LoadingStep.current(this.text) : status = ProgressStepStatus.current;

  /// Creates a completed step
  LoadingStep.completed(this.text) : status = ProgressStepStatus.completed;

  /// Creates an error step
  LoadingStep.error(this.text) : status = ProgressStepStatus.error;
}

/// Specialized loading overlay for session operations
class SessionLoadingOverlay extends StatelessWidget {
  final String operationType; // 'Starting', 'Joining', etc.
  final String currentStep;
  final List<String> allSteps;

  const SessionLoadingOverlay({
    super.key,
    required this.operationType,
    required this.currentStep,
    required this.allSteps,
  });

  @override
  Widget build(BuildContext context) {
    final steps =
        allSteps.map((stepText) {
          if (stepText == currentStep) {
            return LoadingStep.current(stepText);
          } else if (allSteps.indexOf(stepText) <
              allSteps.indexOf(currentStep)) {
            return LoadingStep.completed(stepText);
          } else {
            return LoadingStep.pending(stepText);
          }
        }).toList();

    return LoadingOverlay(
      title: '$operationType Session',
      message: currentStep,
      steps: steps,
    );
  }
}

/// Simple loading overlay without progress steps
class SimpleLoadingOverlay extends StatelessWidget {
  final String title;
  final String message;
  final Widget? extraContent;

  const SimpleLoadingOverlay({
    super.key,
    required this.title,
    required this.message,
    this.extraContent,
  });

  @override
  Widget build(BuildContext context) {
    return LoadingOverlay(
      title: title,
      message: message,
      customContent: extraContent,
      steps: null,
    );
  }
}
