// lib/features/session/presentation/widgets/molecules/language_picker_tile.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/durations.dart';
import 'package:hermes/features/session/presentation/utils/language_helpers.dart';
import '../atoms/language_flag.dart';

/// A selectable tile for language selection with flag, name, and selection state.
/// Used in language picker lists and dropdowns.
class LanguagePickerTile extends StatelessWidget {
  final LanguageOption language;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool showCheckmark;

  const LanguagePickerTile({
    super.key,
    required this.language,
    this.isSelected = false,
    this.onTap,
    this.showCheckmark = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: HermesDurations.fast,
      decoration: BoxDecoration(
        color:
            isSelected
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.3)
                : Colors.transparent,
        borderRadius: BorderRadius.circular(HermesSpacing.sm),
      ),
      child: ListTile(
        onTap: onTap,
        leading: LanguageFlag(flag: language.flag, size: 32, showBorder: true),
        title: Text(
          language.name,
          style: theme.textTheme.bodyLarge?.copyWith(
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        subtitle: Text(
          language.code,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.outline,
          ),
        ),
        trailing:
            showCheckmark && isSelected
                ? Icon(Icons.check_rounded, color: theme.colorScheme.primary)
                : null,
      ),
    );
  }
}
