// lib/features/session/domain/entities/language_selection.dart

import 'package:equatable/equatable.dart';

/// Represents a language selection entity in the domain layer
class LanguageSelection extends Equatable {
  /// Language code (e.g., 'en', 'es', 'fr')
  final String languageCode;

  /// Language name in its native form
  final String nativeName;

  /// Language name in English
  final String englishName;

  /// Flag emoji representing the language
  final String flagEmoji;

  /// Whether the language is supported for speech-to-text
  final bool supportsStt;

  /// Whether the language is supported for text-to-speech
  final bool supportsTts;

  /// Creates a new [LanguageSelection] instance
  const LanguageSelection({
    required this.languageCode,
    required this.nativeName,
    required this.englishName,
    required this.flagEmoji,
    this.supportsStt = true,
    this.supportsTts = true,
  });

  @override
  List<Object> get props => [
    languageCode,
    nativeName,
    englishName,
    flagEmoji,
    supportsStt,
    supportsTts,
  ];
}

/// Common language selections
class LanguageSelections {
  /// English language
  static const english = LanguageSelection(
    languageCode: 'en',
    nativeName: 'English',
    englishName: 'English',
    flagEmoji: '🇺🇸',
  );

  /// Spanish language
  static const spanish = LanguageSelection(
    languageCode: 'es',
    nativeName: 'Español',
    englishName: 'Spanish',
    flagEmoji: '🇪🇸',
  );

  /// French language
  static const french = LanguageSelection(
    languageCode: 'fr',
    nativeName: 'Français',
    englishName: 'French',
    flagEmoji: '🇫🇷',
  );

  /// German language
  static const german = LanguageSelection(
    languageCode: 'de',
    nativeName: 'Deutsch',
    englishName: 'German',
    flagEmoji: '🇩🇪',
  );

  /// Italian language
  static const italian = LanguageSelection(
    languageCode: 'it',
    nativeName: 'Italiano',
    englishName: 'Italian',
    flagEmoji: '🇮🇹',
  );

  /// Portuguese language
  static const portuguese = LanguageSelection(
    languageCode: 'pt',
    nativeName: 'Português',
    englishName: 'Portuguese',
    flagEmoji: '🇵🇹',
  );

  /// Japanese language
  static const japanese = LanguageSelection(
    languageCode: 'ja',
    nativeName: '日本語',
    englishName: 'Japanese',
    flagEmoji: '🇯🇵',
  );

  /// Chinese (Simplified) language
  static const chineseSimplified = LanguageSelection(
    languageCode: 'zh-CN',
    nativeName: '简体中文',
    englishName: 'Chinese (Simplified)',
    flagEmoji: '🇨🇳',
  );

  /// Russian language
  static const russian = LanguageSelection(
    languageCode: 'ru',
    nativeName: 'Русский',
    englishName: 'Russian',
    flagEmoji: '🇷🇺',
  );

  /// Arabic language
  static const arabic = LanguageSelection(
    languageCode: 'ar',
    nativeName: 'العربية',
    englishName: 'Arabic',
    flagEmoji: '🇦🇪',
  );

  /// List of all supported languages
  static const List<LanguageSelection> allLanguages = [
    english,
    spanish,
    french,
    german,
    italian,
    portuguese,
    japanese,
    chineseSimplified,
    russian,
    arabic,
  ];

  /// Get language by code
  static LanguageSelection? getByCode(String code) {
    try {
      return allLanguages.firstWhere(
        (language) => language.languageCode == code,
      );
    } catch (e) {
      return null;
    }
  }
}
