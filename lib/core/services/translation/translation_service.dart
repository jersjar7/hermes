import 'translation_result.dart';

abstract class ITranslationService {
  Future<TranslationResult> translate({
    required String text,
    required String targetLanguageCode,
    String? sourceLanguageCode,
  });
}
