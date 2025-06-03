// lib/features/session/presentation/widgets/atoms/detail_row.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';

/// A simple atom for displaying key-value pairs in info sections.
/// Used in dialogs, info cards, and detail displays.
class DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final double? labelWidth;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;
  final CrossAxisAlignment alignment;

  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 100,
    this.labelStyle,
    this.valueStyle,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: HermesSpacing.xs),
      child: Row(
        crossAxisAlignment: alignment,
        children: [
          if (labelWidth != null)
            SizedBox(
              width: labelWidth,
              child: Text(
                '$label:',
                style:
                    labelStyle ??
                    theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
              ),
            )
          else
            Text(
              '$label:',
              style:
                  labelStyle ??
                  theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
            ),
          if (labelWidth != null) ...[
            Expanded(
              child: Text(
                value,
                style:
                    valueStyle ??
                    theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ] else ...[
            const SizedBox(width: HermesSpacing.sm),
            Expanded(
              child: Text(
                value,
                style:
                    valueStyle ??
                    theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact version for tighter spaces
class CompactDetailRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;

  const CompactDetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: HermesSpacing.xs),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: theme.colorScheme.outline),
            const SizedBox(width: HermesSpacing.xs),
          ],
          Text(
            '$label: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
