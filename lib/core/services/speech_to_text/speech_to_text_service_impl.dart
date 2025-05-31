// lib/core/services/speech_to_text/speech_to_text_service_impl.dart

import 'dart:async';
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

  // For managing finalization timeouts
  Timer? _finalizationTimer;
  String? _lastPartialResult;
  void Function(SpeechResult)? _currentOnResult;

  // Timeout after which we consider a partial result "final"
  static const Duration _finalizationTimeout = Duration(seconds: 3);

  SpeechToTextServiceImpl(this._logger);

  @override
  Future<bool> initialize() async {
    print('🎙️ [STTService] Initializing speech-to-text service...');

    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          _isListening = status == 'listening';
          print('🎙️ [STTService] Status changed: $status');
          _logger.logInfo('STT status: $status', context: 'STT');

          // Handle status changes that might indicate finalization
          if (status == 'notListening' || status == 'done') {
            _handlePotentialFinalization();
          }
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

    // Store the callback for finalization
    _currentOnResult = onResult;

    try {
      await _speech.listen(
        localeId: _locale,
        onResult: (res) {
          final transcript = res.recognizedWords;
          final isFinal = res.finalResult;

          print('📝 [STTService] Result: "$transcript" (final: $isFinal)');

          if (isFinal) {
            // Clear any pending finalization timer
            _finalizationTimer?.cancel();
            _lastPartialResult = null;

            // Emit final result
            final out = SpeechResult(
              transcript: transcript,
              isFinal: true,
              timestamp: DateTime.now(),
              locale: _locale,
            );
            onResult(out);
          } else {
            // Handle partial result
            _lastPartialResult = transcript;

            // Emit partial result
            final out = SpeechResult(
              transcript: transcript,
              isFinal: false,
              timestamp: DateTime.now(),
              locale: _locale,
            );
            onResult(out);

            // Set up finalization timer for partial results
            _startFinalizationTimer();
          }
        },
        cancelOnError: true,
        partialResults: true,
        // Configure listening session
        listenFor: const Duration(minutes: 10), // Listen for longer periods
        pauseFor: const Duration(
          seconds: 5,
        ), // Pause detection after 5 seconds of silence
      );
    } catch (e) {
      print('❌ [STTService] Start listening failed: $e');
      onError(Exception('Failed to start listening: $e'));
    }
  }

  void _startFinalizationTimer() {
    // Cancel any existing timer
    _finalizationTimer?.cancel();

    // Start new timer
    _finalizationTimer = Timer(_finalizationTimeout, () {
      _handlePotentialFinalization();
    });
  }

  void _handlePotentialFinalization() {
    if (_lastPartialResult != null &&
        _lastPartialResult!.isNotEmpty &&
        _currentOnResult != null) {
      print(
        '⏰ [STTService] Finalizing partial result due to timeout: "$_lastPartialResult"',
      );

      // Create a final result from the last partial result
      final finalResult = SpeechResult(
        transcript: _lastPartialResult!,
        isFinal: true,
        timestamp: DateTime.now(),
        locale: _locale,
      );

      _currentOnResult!(finalResult);

      // Clear the partial result
      _lastPartialResult = null;
    }

    _finalizationTimer?.cancel();
  }

  @override
  Future<void> stopListening() async {
    print('🛑 [STTService] Stopping listening...');

    // Finalize any pending partial result
    _handlePotentialFinalization();

    await _speech.stop();
    _isListening = false;
    _currentOnResult = null;
    _finalizationTimer?.cancel();
  }

  @override
  Future<void> cancel() async {
    print('❌ [STTService] Cancelling listening...');

    await _speech.cancel();
    _isListening = false;
    _currentOnResult = null;
    _lastPartialResult = null;
    _finalizationTimer?.cancel();
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

  @override
  void dispose() {
    _finalizationTimer?.cancel();
    _currentOnResult = null;
    _lastPartialResult = null;
  }
}
