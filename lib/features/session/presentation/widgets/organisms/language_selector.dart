// lib/features/session/presentation/widgets/organisms/language_selector.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/features/session/presentation/controllers/language_selection_controller.dart';
import 'package:hermes/features/session/presentation/utils/language_helpers.dart';
import '../molecules/language_picker_tile.dart';

/// Complete language selection interface with search and scrollable list.
/// Used in session setup to choose speaker/target languages.
class LanguageSelector extends ConsumerWidget {
  final String? selectedLanguageCode;
  final ValueChanged<LanguageOption>? onLanguageSelected;
  final double maxHeight;
  final bool showSearch;

  const LanguageSelector({
    super.key,
    this.selectedLanguageCode,
    this.onLanguageSelected,
    this.maxHeight = 400,
    this.showSearch = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final languageState = ref.watch(languageSelectionProvider);
    final theme = Theme.of(context);

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(HermesSpacing.md),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showSearch) _buildSearchField(context, ref),

          Flexible(child: _buildLanguageList(context, ref, languageState)),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Search languages...',
          prefixIcon: const Icon(HermesIcons.translating),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(HermesSpacing.sm),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: theme.colorScheme.surfaceContainerHighest,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: HermesSpacing.md,
            vertical: HermesSpacing.sm,
          ),
        ),
        onChanged: (query) {
          ref.read(languageSelectionProvider.notifier).updateSearch(query);
        },
      ),
    );
  }

  Widget _buildLanguageList(
    BuildContext context,
    WidgetRef ref,
    LanguageSelectionState state,
  ) {
    if (state.filtered.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      shrinkWrap: true,
      itemCount: state.filtered.length,
      itemBuilder: (context, index) {
        final language = state.filtered[index];
        final isSelected = _isLanguageSelected(language);

        return LanguagePickerTile(
          language: language,
          isSelected: isSelected,
          onTap: () => _handleLanguageSelection(ref, language),
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.search_off_rounded,
              size: 32,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: HermesSpacing.sm),
            Text(
              'No languages found',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _isLanguageSelected(LanguageOption language) {
    return selectedLanguageCode == language.code;
  }

  void _handleLanguageSelection(WidgetRef ref, LanguageOption language) {
    ref.read(languageSelectionProvider.notifier).selectLanguage(language);
    onLanguageSelected?.call(language);
  }
}
