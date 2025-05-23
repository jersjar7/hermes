import 'package:hermes/core/services/text_to_speech/text_to_speech_service_impl.dart';

void main() async {
  final tts = TextToSpeechServiceImpl();
  await tts.initialize();
  await tts.setLanguage('en-US');
  await tts.setPitch(1.0);
  await tts.setSpeechRate(1.0);

  print('🗣️ Speaking...');
  await tts.speak("Hello! This is a test of the text to speech system.");
}
