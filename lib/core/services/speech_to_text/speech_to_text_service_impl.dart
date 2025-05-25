// lib/core/services/speech_to_text/speech_to_text_service_impl.dart
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../logger/logger_service.dart';
import 'speech_to_text_service.dart';
import 'speech_result.dart';

class SpeechToTextServiceImpl implements ISpeechToTextService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ILoggerService _logger;
  bool _isAvailable = false;
  bool _isListening = false;
  String _locale = 'en_US';

  SpeechToTextServiceImpl(this._logger);

  @override
  Future<bool> initialize() async {
    if (!await Permission.microphone.isGranted) {
      final res = await Permission.microphone.request();
      if (!res.isGranted) {
        _logger.logError('Mic permission denied', context: 'STT');
        return false;
      }
    }
    _isAvailable = await _speech.initialize(
      onStatus: (status) {
        _isListening = status == 'listening';
        _logger.logInfo('STT status: $status', context: 'STT');
      },
      onError: (err) => _logger.logError('STT error: $err', context: 'STT'),
    );
    return _isAvailable;
  }

  @override
  Future<void> startListening({
    required void Function(SpeechResult) onResult,
    required void Function(Exception) onError,
  }) async {
    if (!_isAvailable) {
      final msg = 'STT not available';
      _logger.logError(msg, context: 'STT');
      onError(Exception(msg));
      return;
    }
    await _speech.listen(
      localeId: _locale,
      onResult: (res) {
        final out = SpeechResult(
          transcript: res.recognizedWords,
          isFinal: res.finalResult,
          timestamp: DateTime.now(),
          locale: _locale,
        );
        onResult(out);
      },
      cancelOnError: true,
      partialResults: true,
    );
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
  bool get isAvailable => _isAvailable;
  @override
  bool get isListening => _isListening;
  @override
  Future<bool> get hasPermission async => await Permission.microphone.isGranted;

  @override
  Future<List<LocaleName>> getSupportedLocales() async {
    final locales = await _speech.locales();
    return locales
        .map((e) => LocaleName(localeId: e.localeId, name: e.name))
        .toList();
  }

  @override
  Future<void> setLocale(String localeId) async {
    _locale = localeId;
  }
}
