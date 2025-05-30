// lib/core/presentation/widgets/buttons/primary_button.dart

import 'package:flutter/material.dart';
import '../../constants/spacing.dart';
import '../../constants/durations.dart';

/// Primary CTA button with Hermes styling.
/// Supports loading state and full-width option.
class PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool isFullWidth;
  final IconData? icon;

  const PrimaryButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.isFullWidth = false,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final child = _ButtonContent(
      label: label,
      icon: icon,
      isLoading: isLoading,
    );

    return SizedBox(
      width: isFullWidth ? double.infinity : null,
      height: 48.0,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(
            horizontal: icon != null ? HermesSpacing.md : HermesSpacing.lg,
            vertical: HermesSpacing.buttonPadding,
          ),
        ),
        child: AnimatedSwitcher(duration: HermesDurations.fast, child: child),
      ),
    );
  }
}

class _ButtonContent extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool isLoading;

  const _ButtonContent({
    required this.label,
    this.icon,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }

    if (icon != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20),
          const SizedBox(width: HermesSpacing.xs),
          Text(label),
        ],
      );
    }

    return Text(label);
  }
}
