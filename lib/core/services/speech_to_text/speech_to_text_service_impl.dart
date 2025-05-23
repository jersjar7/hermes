import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';

import 'speech_to_text_service.dart';
import 'speech_result.dart';

class SpeechToTextServiceImpl implements ISpeechToTextService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _isAvailable = false;
  String _currentLocaleId = 'en_US';

  @override
  Future<bool> initialize() async {
    final micStatus = await Permission.microphone.status;
    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) return false;
    }

    _isAvailable = await _speech.initialize(
      onStatus: (status) => _isListening = status == 'listening',
      onError: (error) => print('STT error: $error'),
    );

    return _isAvailable;
  }

  @override
  Future<void> startListening({
    required void Function(SpeechResult result) onResult,
    required void Function(Exception error) onError,
  }) async {
    if (!_isAvailable) throw Exception('STT not available');

    try {
      await _speech.listen(
        localeId: _currentLocaleId,
        onResult: (stt.SpeechRecognitionResult result) {
          onResult(
            SpeechResult(
              transcript: result.recognizedWords,
              isFinal: result.finalResult,
              timestamp: DateTime.now(),
              locale: _currentLocaleId,
            ),
          );
        },
        cancelOnError: true,
        partialResults: true,
      );
    } catch (e) {
      onError(Exception(e.toString()));
    }
  }

  @override
  Future<void> stopListening() async {
    await _speech.stop();
    _isListening = false;
  }

  @override
  Future<void> cancel() async {
    await _speech.cancel();
    _isListening = false;
  }

  @override
  bool get isListening => _isListening;

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<bool> get hasPermission => Permission.microphone.isGranted;

  @override
  Future<List<LocaleName>> getSupportedLocales() async {
    final locales = await _speech.locales();
    return locales
        .map((e) => LocaleName(localeId: e.localeId, name: e.name))
        .toList();
  }

  @override
  Future<void> setLocale(String localeId) async {
    _currentLocaleId = localeId;
  }
}
