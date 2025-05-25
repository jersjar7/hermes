// lib/core/services/translation/translation_result.dart
/// Represents the result of a translation operation.
class TranslationResult {
  final String translatedText;
  final String targetLanguageCode;
  final String? sourceLanguageCode;
  final String? originalText;

  TranslationResult({
    required this.translatedText,
    required this.targetLanguageCode,
    this.sourceLanguageCode,
    this.originalText,
  });
}
