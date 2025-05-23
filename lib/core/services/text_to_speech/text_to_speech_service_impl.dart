import 'package:flutter_tts/flutter_tts.dart';
import 'text_to_speech_service.dart';

enum TtsState { playing, stopped }

class TextToSpeechServiceImpl implements ITextToSpeechService {
  final FlutterTts _tts = FlutterTts();
  TtsState _ttsState = TtsState.stopped;

  TextToSpeechServiceImpl() {
    _tts.setStartHandler(() {
      _ttsState = TtsState.playing;
    });

    _tts.setCompletionHandler(() {
      _ttsState = TtsState.stopped;
    });

    _tts.setCancelHandler(() {
      _ttsState = TtsState.stopped;
    });

    _tts.setErrorHandler((msg) {
      _ttsState = TtsState.stopped;
    });
  }

  @override
  Future<void> initialize() async {
    await _tts.setLanguage('en-US');
    await _tts.setPitch(1.0);
    await _tts.setSpeechRate(1.0);
  }

  @override
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
  }

  @override
  Future<bool> isSpeaking() async {
    return _ttsState == TtsState.playing;
  }

  @override
  Future<void> setLanguage(String languageCode) async {
    await _tts.setLanguage(languageCode);
  }

  @override
  Future<void> setPitch(double pitch) async {
    await _tts.setPitch(pitch);
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    await _tts.setSpeechRate(rate);
  }

  @override
  Future<List<TtsLanguage>> getLanguages() async {
    final langs = await _tts.getLanguages;
    return langs.map((code) => TtsLanguage(code: code, name: code)).toList();
  }
}
