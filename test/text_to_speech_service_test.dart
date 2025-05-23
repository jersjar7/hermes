import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service_impl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  group('TextToSpeechServiceImpl', () {
    final tts = TextToSpeechServiceImpl();

    test('initializes without error', () async {
      await tts.initialize();
      expect(true, isTrue); // Just ensures no crash
    });

    test('returns list of languages', () async {
      final languages = await tts.getLanguages();
      expect(languages, isNotEmpty);
    });
  });
}
