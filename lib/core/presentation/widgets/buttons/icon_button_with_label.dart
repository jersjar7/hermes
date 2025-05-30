// lib/core/presentation/widgets/buttons/icon_button_with_label.dart

import 'package:flutter/material.dart';
import '../../constants/spacing.dart';

/// Vertical icon button with label underneath.
/// Useful for grid layouts and action sheets.
class IconButtonWithLabel extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final Color? iconColor;

  const IconButtonWithLabel({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = iconColor ?? theme.colorScheme.primary;

    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(HermesSpacing.sm),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 32,
              color: onPressed != null ? color : theme.disabledColor,
            ),
            const SizedBox(height: HermesSpacing.xs),
            Text(
              label,
              style: theme.textTheme.labelSmall?.copyWith(
                color: onPressed != null ? null : theme.disabledColor,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
