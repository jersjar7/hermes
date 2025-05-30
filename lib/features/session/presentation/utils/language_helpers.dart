// lib/features/session/presentation/utils/language_helpers.dart

/// UI-specific language utilities for the session feature.
/// Complements core language utils with presentation helpers.
class LanguageHelpers {
  // Prevent instantiation
  LanguageHelpers._();

  /// Common languages for quick selection.
  /// Ordered by global speaker population.
  static const List<LanguageOption> commonLanguages = [
    LanguageOption('en-US', 'English', '🇺🇸'),
    LanguageOption('es-ES', 'Spanish', '🇪🇸'),
    LanguageOption('zh-CN', 'Chinese', '🇨🇳'),
    LanguageOption('hi-IN', 'Hindi', '🇮🇳'),
    LanguageOption('ar-SA', 'Arabic', '🇸🇦'),
    LanguageOption('pt-BR', 'Portuguese', '🇧🇷'),
    LanguageOption('ru-RU', 'Russian', '🇷🇺'),
    LanguageOption('ja-JP', 'Japanese', '🇯🇵'),
    LanguageOption('de-DE', 'German', '🇩🇪'),
    LanguageOption('fr-FR', 'French', '🇫🇷'),
  ];

  /// Gets a language option by code.
  /// Returns null if not found in common languages.
  static LanguageOption? getLanguageOption(String code) {
    try {
      return commonLanguages.firstWhere((lang) => lang.code == code);
    } catch (_) {
      return null;
    }
  }

  /// Searches languages by name or code.
  /// Case-insensitive partial matching.
  static List<LanguageOption> searchLanguages(String query) {
    if (query.isEmpty) return commonLanguages;

    final lowercaseQuery = query.toLowerCase();
    return commonLanguages.where((lang) {
      return lang.name.toLowerCase().contains(lowercaseQuery) ||
          lang.code.toLowerCase().contains(lowercaseQuery);
    }).toList();
  }

  /// Groups languages by first letter for alphabetical lists.
  static Map<String, List<LanguageOption>> groupByFirstLetter(
    List<LanguageOption> languages,
  ) {
    final grouped = <String, List<LanguageOption>>{};

    for (final lang in languages) {
      final firstLetter = lang.name[0].toUpperCase();
      grouped.putIfAbsent(firstLetter, () => []).add(lang);
    }

    return grouped;
  }
}

/// Represents a language with display information.
class LanguageOption {
  final String code;
  final String name;
  final String flag;

  const LanguageOption(this.code, this.name, this.flag);

  /// Full display label with flag and name.
  String get displayLabel => '$flag $name';

  /// Short label with just the flag and language code.
  String get shortLabel => '$flag $code';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LanguageOption &&
          runtimeType == other.runtimeType &&
          code == other.code;

  @override
  int get hashCode => code.hashCode;
}
