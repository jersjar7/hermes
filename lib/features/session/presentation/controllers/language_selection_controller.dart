// lib/features/session/presentation/controllers/language_selection_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/language_helpers.dart';

/// State for language selection.
/// Immutable to ensure predictable updates.
class LanguageSelectionState {
  final LanguageOption? selected;
  final List<LanguageOption> available;
  final String searchQuery;
  final List<LanguageOption> filtered;

  const LanguageSelectionState({
    this.selected,
    required this.available,
    this.searchQuery = '',
    required this.filtered,
  });

  /// Creates initial state with all languages.
  factory LanguageSelectionState.initial() {
    return LanguageSelectionState(
      available: LanguageHelpers.commonLanguages,
      filtered: LanguageHelpers.commonLanguages,
    );
  }

  /// Creates a copy with optional overrides.
  LanguageSelectionState copyWith({
    LanguageOption? selected,
    List<LanguageOption>? available,
    String? searchQuery,
    List<LanguageOption>? filtered,
  }) {
    return LanguageSelectionState(
      selected: selected ?? this.selected,
      available: available ?? this.available,
      searchQuery: searchQuery ?? this.searchQuery,
      filtered: filtered ?? this.filtered,
    );
  }
}

/// Controls language selection state and search.
class LanguageSelectionController
    extends StateNotifier<LanguageSelectionState> {
  LanguageSelectionController() : super(LanguageSelectionState.initial());

  /// Selects a language.
  void selectLanguage(LanguageOption language) {
    state = state.copyWith(selected: language);
  }

  /// Updates search query and filters results.
  void updateSearch(String query) {
    final filtered = LanguageHelpers.searchLanguages(query);
    state = state.copyWith(searchQuery: query, filtered: filtered);
  }

  /// Clears current selection.
  void clearSelection() {
    state = state.copyWith(selected: null);
  }
}

/// Provider for language selection controller.
final languageSelectionProvider =
    StateNotifierProvider<LanguageSelectionController, LanguageSelectionState>((
      ref,
    ) {
      return LanguageSelectionController();
    });
