abstract class ITranslationService {
  Future<String> translate({
    required String text,
    required String targetLanguageCode,
    String? sourceLanguageCode,
  });
}
