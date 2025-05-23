import 'package:flutter_test/flutter_test.dart';
import 'package:hermes/core/services/translation/translation_service_impl.dart';

void main() {
  group('TranslationService', () {
    final service = TranslationServiceImpl(
      apiKey: 'AIzaSyCLILZYMgAPdqa_iw_8Yf8EjMdzBdGz11A',
    );

    test('translates text from English to Spanish', () async {
      final result = await service.translate(
        text: 'Hello this is a test',
        targetLanguageCode: 'es',
      );
      expect(result, isNotEmpty, reason: 'Translation result: $result');
    });
  });
}
