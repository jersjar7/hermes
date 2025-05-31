// lib/core/services/speech_to_text/speech_to_text_service_impl.dart

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
    print('🎙️ [STTService] Initializing speech-to-text service...');

    // Remove permission check - StartSessionUseCase handles this
    // The permission should already be granted when this is called

    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          _isListening = status == 'listening';
          print('🎙️ [STTService] Status changed: $status');
          _logger.logInfo('STT status: $status', context: 'STT');
        },
        onError: (err) {
          print('❌ [STTService] Error: $err');
          _logger.logError('STT error: $err', context: 'STT');
        },
      );

      print('📱 [STTService] Initialization result: $_isAvailable');

      if (_isAvailable) {
        // Log available locales for debugging
        final locales = await _speech.locales();
        print('🌍 [STTService] Available locales: ${locales.length}');
        for (final locale in locales.take(5)) {
          print('   - ${locale.localeId}: ${locale.name}');
        }
      } else {
        print(
          '⚠️ [STTService] Speech recognition not available on this device',
        );
      }

      return _isAvailable;
    } catch (e, stackTrace) {
      print('💥 [STTService] Initialization failed: $e');
      _logger.logError(
        'STT initialization failed',
        error: e,
        stackTrace: stackTrace,
        context: 'STT',
      );
      return false;
    }
  }

  @override
  Future<void> startListening({
    required void Function(SpeechResult) onResult,
    required void Function(Exception) onError,
  }) async {
    if (!_isAvailable) {
      final msg = 'Speech recognition not available';
      print('❌ [STTService] $msg');
      _logger.logError(msg, context: 'STT');
      onError(Exception(msg));
      return;
    }

    print('🎤 [STTService] Starting to listen with locale: $_locale');

    try {
      await _speech.listen(
        localeId: _locale,
        onResult: (res) {
          print(
            '📝 [STTService] Result: "${res.recognizedWords}" (final: ${res.finalResult})',
          );
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
    } catch (e) {
      print('❌ [STTService] Start listening failed: $e');
      onError(Exception('Failed to start listening: $e'));
    }
  }

  @override
  Future<void> stopListening() async {
    print('🛑 [STTService] Stopping listening...');
    await _speech.stop();
    _isListening = false;
  }

  @override
  Future<void> cancel() async {
    print('❌ [STTService] Cancelling listening...');
    await _speech.cancel();
    _isListening = false;
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> get hasPermission async {
    // This is now just informational - permission handled by PermissionService
    return _isAvailable;
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
    print('🌍 [STTService] Setting locale to: $localeId');
    _locale = localeId;
  }
}
