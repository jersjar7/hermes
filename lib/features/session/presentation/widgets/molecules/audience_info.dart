// lib/features/session/presentation/widgets/molecules/audience_info.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';

/// Displays audience count and language distribution in a compact format.
/// Example: "12 listeners: 8 Spanish, 4 French"
class AudienceInfo extends StatelessWidget {
  final int totalListeners;
  final Map<String, int> languageDistribution;
  final bool showIcon;
  final TextStyle? textStyle;

  const AudienceInfo({
    super.key,
    required this.totalListeners,
    required this.languageDistribution,
    this.showIcon = true,
    this.textStyle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style = textStyle ?? theme.textTheme.bodySmall;

    if (totalListeners == 0) {
      return _buildEmptyState(context, style);
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          Icon(HermesIcons.people, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: HermesSpacing.xs),
        ],
        Flexible(
          child: Text(
            _buildAudienceText(),
            style: style?.copyWith(color: theme.colorScheme.primary),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, TextStyle? style) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon) ...[
          Icon(HermesIcons.people, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: HermesSpacing.xs),
        ],
        Text(
          'No listeners yet',
          style: style?.copyWith(color: theme.colorScheme.outline),
        ),
      ],
    );
  }

  String _buildAudienceText() {
    final listenerText = totalListeners == 1 ? 'listener' : 'listeners';

    if (languageDistribution.isEmpty) {
      return '$totalListeners $listenerText';
    }

    // Sort languages by count (descending)
    final sortedLanguages =
        languageDistribution.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    // Build language list
    final languageList = sortedLanguages
        .map((entry) => '${entry.value} ${entry.key}')
        .join(', ');

    return '$totalListeners $listenerText: $languageList';
  }
}

/// Compact version for tight spaces
class CompactAudienceInfo extends StatelessWidget {
  final int totalListeners;
  final bool showIcon;

  const CompactAudienceInfo({
    super.key,
    required this.totalListeners,
    this.showIcon = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showIcon)
          Icon(HermesIcons.people, size: 14, color: theme.colorScheme.outline),
        if (showIcon) const SizedBox(width: 4),
        Text(
          totalListeners.toString(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
