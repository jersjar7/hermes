// lib/core/services/text_to_speech/text_to_speech_service_impl.dart
import 'package:flutter_tts/flutter_tts.dart';
import '../logger/logger_service.dart';
import 'text_to_speech_service.dart';
import 'tts_settings.dart';

class TextToSpeechServiceImpl implements ITextToSpeechService {
  final FlutterTts _tts = FlutterTts();
  final ILoggerService _logger;
  bool _isSpeaking = false;

  TextToSpeechServiceImpl(this._logger) {
    _tts.setStartHandler(() {
      _isSpeaking = true;
    });
    _tts.setCompletionHandler(() {
      _isSpeaking = false;
    });
    _tts.setCancelHandler(() {
      _isSpeaking = false;
    });
    _tts.setErrorHandler((msg) {
      _isSpeaking = false;
      _logger.logError('TTS error: $msg', context: 'TTS');
    });
  }

  @override
  Future<void> initialize() async {
    final cfg = TtsSettings.defaultSettings();
    await setLanguage(cfg.languageCode);
    await setPitch(cfg.pitch);
    await setSpeechRate(cfg.speechRate);
  }

  @override
  Future<void> speak(String text) async {
    await _tts.speak(text);
  }

  @override
  Future<void> stop() async {
    await _tts.stop();
    _isSpeaking = false;
  }

  @override
  Future<bool> isSpeaking() async {
    return _isSpeaking;
  }

  @override
  Future<void> setLanguage(String code) async {
    await _tts.setLanguage(code);
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
    return langs.map((l) => TtsLanguage(code: l, name: l)).toList();
  }
}
