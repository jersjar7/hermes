// lib/core/services/speech_to_text/speech_to_text_service_impl.dart
import 'package:hermes/core/service_locator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:hermes/core/services/logger/logger_service.dart';

import 'speech_to_text_service.dart';
import 'speech_result.dart';

class SpeechToTextServiceImpl implements ISpeechToTextService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ILoggerService _logger = getIt<ILoggerService>();

  bool _isListening = false;
  bool _isAvailable = false;
  String _currentLocaleId = 'en_US';

  @override
  Future<bool> initialize() async {
    _logger.logInfo('Initializing STT service...', context: 'STT');

    final micStatus = await Permission.microphone.status;
    _logger.logInfo('Mic permission status: $micStatus', context: 'STT');

    if (!micStatus.isGranted) {
      final result = await Permission.microphone.request();
      if (!result.isGranted) {
        _logger.logError('Microphone permission denied', context: 'STT');
        return false;
      }
    }

    _isAvailable = await _speech.initialize(
      onStatus: (status) {
        _isListening = status == 'listening';
        _logger.logInfo('STT status: $status', context: 'STT');
      },
      onError:
          (error) =>
              _logger.logError('STT plugin error: $error', context: 'STT'),
    );

    _logger.logInfo('STT available: $_isAvailable', context: 'STT');
    return _isAvailable;
  }

  @override
  Future<void> startListening({
    required void Function(SpeechResult result) onResult,
    required void Function(Exception error) onError,
  }) async {
    if (!_isAvailable) {
      final msg = 'STT not available';
      _logger.logError(msg, context: 'STT');
      onError(Exception(msg));
      return;
    }

    try {
      await _speech.listen(
        localeId: _currentLocaleId,
        onResult: (stt.SpeechRecognitionResult result) {
          final output = SpeechResult(
            transcript: result.recognizedWords,
            isFinal: result.finalResult,
            timestamp: DateTime.now(),
            locale: _currentLocaleId,
          );
          _logger.logInfo('STT heard: "${output.transcript}"', context: 'STT');
          onResult(output);
        },
        cancelOnError: true,
        partialResults: true,
      );
    } catch (e) {
      _logger.logError('STT listening failed', error: e, context: 'STT');
      onError(Exception(e.toString()));
    }
  }

  @override
  Future<void> stopListening() async {
    await _speech.stop();
    _isListening = false;
    _logger.logInfo('STT stopped listening', context: 'STT');
  }

  @override
  Future<void> cancel() async {
    await _speech.cancel();
    _isListening = false;
    _logger.logInfo('STT listening cancelled', context: 'STT');
  }

  @override
  bool get isListening => _isListening;

  @override
  bool get isAvailable => _isAvailable;

  @override
  Future<bool> get hasPermission async {
    final granted = await Permission.microphone.isGranted;
    _logger.logInfo('Mic permission granted? $granted', context: 'STT');
    return granted;
  }

  @override
  Future<List<LocaleName>> getSupportedLocales() async {
    final locales = await _speech.locales();
    return locales
        .map((e) => LocaleName(localeId: e.localeId, name: e.name))
        .toList();
  }

  @override
  Future<void> setLocale(String localeId) async {
    _logger.logInfo('STT locale set to $localeId', context: 'STT');
    _currentLocaleId = localeId;
  }
}
