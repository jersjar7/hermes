import 'package:hermes/core/services/translation/translation_service_impl.dart';

void main() async {
  final service = TranslationServiceImpl(
    apiKey: 'AIzaSyCLILZYMgAPdqa_iw_8Yf8EjMdzBdGz11A',
  );

  final result = await service.translate(
    text: 'Hello this is a test',
    targetLanguageCode: 'es',
  );

  print('🟢 Translated Text: $result');
}
