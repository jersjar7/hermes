// lib/core/services/speech_to_text/speech_to_text_service_impl.dart

import 'dart:async';
import 'package:speech_to_text/speech_recognition_error.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../logger/logger_service.dart';
import 'speech_to_text_service.dart';
import 'speech_result.dart';

class SpeechToTextServiceImpl implements ISpeechToTextService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ILoggerService _logger;
  bool _isAvailable = false;
  bool _isListening = false;
  String _locale = 'en-US';

  // For managing finalization timeouts
  Timer? _finalizationTimer;
  Timer? _restartTimer;
  String? _lastPartialResult;
  void Function(SpeechResult)? _currentOnResult;
  void Function(Exception)? _currentOnError;

  // Timeout after which we consider a partial result "final"
  static const Duration _finalizationTimeout = Duration(seconds: 2);
  static const Duration _restartDelay = Duration(milliseconds: 500);

  SpeechToTextServiceImpl(this._logger);

  @override
  Future<bool> initialize() async {
    print('🎙️ [STTService] Initializing speech-to-text service...');

    try {
      _isAvailable = await _speech.initialize(
        onStatus: (status) {
          print('🎙️ [STTService] Status changed: $status');
          _logger.logInfo('STT status: $status', context: 'STT');

          final wasListening = _isListening;
          _isListening = status == 'listening';

          // Handle status changes
          if (status == 'notListening' || status == 'done') {
            _handlePotentialFinalization();

            // Auto-restart listening if we were in a listening session
            if (wasListening && _currentOnResult != null) {
              _scheduleRestart();
            }
          }
        },
        onError: (err) {
          print('❌ [STTService] Error: $err');
          _logger.logError('STT error: $err', context: 'STT');
          _handleSpeechError(err);
        },
      );

      print('📱 [STTService] Initialization result: $_isAvailable');

      if (_isAvailable) {
        final locales = await _speech.locales();
        print('🌍 [STTService] Available locales: ${locales.length}');
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
      onError(Exception(msg));
      return;
    }

    print('🎤 [STTService] Starting to listen with locale: $_locale');

    // Store callbacks
    _currentOnResult = onResult;
    _currentOnError = onError;

    await _startListeningInternal();
  }

  Future<void> _startListeningInternal() async {
    try {
      await _speech.listen(
        localeId: _locale,
        onResult: (res) {
          final transcript = res.recognizedWords.trim();
          final isFinal = res.finalResult;

          print(
            '📝 [STTService] Result: "$transcript" (final: $isFinal, confidence: ${res.confidence})',
          );

          if (transcript.isNotEmpty) {
            if (isFinal) {
              // Clear timers and emit final result
              _finalizationTimer?.cancel();
              _lastPartialResult = null;

              final out = SpeechResult(
                transcript: transcript,
                isFinal: true,
                timestamp: DateTime.now(),
                locale: _locale,
              );

              // 🎯 CRITICAL: Check if callback still exists before calling
              if (_currentOnResult != null) {
                _currentOnResult!(out);
              }

              // Continue listening for more speech
              _scheduleRestart();
            } else {
              // Handle partial result
              _lastPartialResult = transcript;

              final out = SpeechResult(
                transcript: transcript,
                isFinal: false,
                timestamp: DateTime.now(),
                locale: _locale,
              );

              // 🎯 CRITICAL: Check if callback still exists before calling
              if (_currentOnResult != null) {
                _currentOnResult!(out);
              }

              // Set up finalization timer
              _startFinalizationTimer();
            }
          }
        },
        cancelOnError: false, // Don't cancel on errors, handle them gracefully
        partialResults: true,
        listenFor: const Duration(seconds: 30), // Listen for longer periods
        pauseFor: const Duration(seconds: 3), // Pause detection after 3 seconds
      );
    } catch (e) {
      print('❌ [STTService] Start listening failed: $e');
      _handleSpeechError(stt.SpeechRecognitionError('start_error', true));
    }
  }

  void _handleSpeechError(stt.SpeechRecognitionError error) {
    print('🔧 [STTService] Handling speech error: ${error.errorMsg}');

    // Handle different types of errors
    switch (error.errorMsg) {
      case 'error_no_match':
        // No speech detected - this is normal, just restart listening
        print('🔄 [STTService] No speech detected, restarting...');
        _scheduleRestart();
        break;

      case 'error_speech_timeout':
        // Speech timeout - restart listening
        print('🔄 [STTService] Speech timeout, restarting...');
        _scheduleRestart();
        break;

      case 'error_audio':
        // Audio error - might be temporary, try restarting
        print('🔄 [STTService] Audio error, attempting restart...');
        _scheduleRestart();
        break;

      case 'error_network':
        // Network error - inform user but try to restart
        print('🌐 [STTService] Network error, will retry...');
        // 🎯 CRITICAL: Check if callback still exists before calling
        if (_currentOnError != null) {
          _currentOnError!(Exception('Network error, retrying...'));
        }
        _scheduleRestart();
        break;

      default:
        // Other errors - inform user
        print('❌ [STTService] Unhandled error: ${error.errorMsg}');
        if (error.permanent && _currentOnError != null) {
          _currentOnError!(
            Exception('Speech recognition error: ${error.errorMsg}'),
          );
        } else {
          _scheduleRestart();
        }
        break;
    }
  }

  void _scheduleRestart() {
    if (_currentOnResult == null) return; // Not in a listening session

    _restartTimer?.cancel();
    _restartTimer = Timer(_restartDelay, () {
      if (_currentOnResult != null && _isAvailable) {
        print('🔄 [STTService] Auto-restarting listening...');
        _startListeningInternal();
      }
    });
  }

  void _startFinalizationTimer() {
    _finalizationTimer?.cancel();
    _finalizationTimer = Timer(_finalizationTimeout, () {
      _handlePotentialFinalization();
    });
  }

  // IMPROVED: Enhanced finalization with safety checks
  void _handlePotentialFinalization() {
    // 🎯 CRITICAL: Only finalize if we still have active callbacks
    if (_lastPartialResult != null &&
        _lastPartialResult!.isNotEmpty &&
        _currentOnResult != null) {
      // Check if callback still exists
      print('⏰ [STTService] Finalizing partial result: "$_lastPartialResult"');

      final finalResult = SpeechResult(
        transcript: _lastPartialResult!,
        isFinal: true,
        timestamp: DateTime.now(),
        locale: _locale,
      );

      // Double-check callback still exists before calling
      if (_currentOnResult != null) {
        _currentOnResult!(finalResult);
      }
      _lastPartialResult = null;
    }

    _finalizationTimer?.cancel();
    _finalizationTimer = null;
  }

  // IMPROVED: Enhanced stop method with proper cleanup order
  @override
  Future<void> stopListening() async {
    print('🛑 [STTService] Stopping listening...');

    // 🎯 CRITICAL: Clear callbacks FIRST to stop processing new results
    final oldOnResult = _currentOnResult;

    _currentOnResult = null;
    _currentOnError = null;

    // Cancel timers
    _finalizationTimer?.cancel();
    _finalizationTimer = null;
    _restartTimer?.cancel();
    _restartTimer = null;

    // Finalize any pending result ONLY if we had active callbacks
    if (oldOnResult != null) {
      _handlePotentialFinalization();
    }

    // Stop the speech service
    try {
      await _speech.stop();
      print('✅ [STTService] Speech service stopped');
    } catch (e) {
      print('⚠️ [STTService] Error stopping speech service: $e');
    }

    _isListening = false;
    _lastPartialResult = null;

    print('✅ [STTService] Listening stopped completely');
  }

  // IMPROVED: Enhanced cancel method with immediate cleanup
  @override
  Future<void> cancel() async {
    print('❌ [STTService] Cancelling listening...');

    // 🎯 CRITICAL: Clear everything immediately
    _currentOnResult = null;
    _currentOnError = null;
    _finalizationTimer?.cancel();
    _finalizationTimer = null;
    _restartTimer?.cancel();
    _restartTimer = null;

    try {
      await _speech.cancel();
      print('✅ [STTService] Speech service cancelled');
    } catch (e) {
      print('⚠️ [STTService] Error cancelling speech service: $e');
    }

    _isListening = false;
    _lastPartialResult = null;

    print('✅ [STTService] Listening cancelled completely');
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get isListening => _isListening;

  @override
  Future<bool> get hasPermission async => _isAvailable;

  @override
  Future<void> setLocale(String localeId) async {
    print('🌍 [STTService] Setting locale to: $localeId');

    // Validate that the locale is supported
    final supportedLocales = await getSupportedLocales();

    // Check for exact match first
    bool isSupported = supportedLocales.any(
      (locale) => locale.localeId.toLowerCase() == localeId.toLowerCase(),
    );

    // If no exact match, try with format conversion (dash <-> underscore)
    if (!isSupported) {
      final alternateFormat =
          localeId.contains('-')
              ? localeId.replaceAll('-', '_')
              : localeId.replaceAll('_', '-');

      isSupported = supportedLocales.any(
        (locale) =>
            locale.localeId.toLowerCase() == alternateFormat.toLowerCase(),
      );

      if (isSupported) {
        print('🔄 [STTService] Using alternate format: $alternateFormat');
        _locale = alternateFormat;
        print('✅ [STTService] Successfully set locale to: $_locale');
        return;
      }
    }

    // If still no match, try language part only (e.g., 'es' from 'es-ES')
    if (!isSupported) {
      final languagePart = localeId.split(RegExp(r'[-_]'))[0];
      isSupported = supportedLocales.any(
        (locale) =>
            locale.localeId.split(RegExp(r'[-_]'))[0].toLowerCase() ==
            languagePart.toLowerCase(),
      );

      if (isSupported) {
        // Find the first matching locale for this language
        final matchingLocale = supportedLocales.firstWhere(
          (locale) =>
              locale.localeId.split(RegExp(r'[-_]'))[0].toLowerCase() ==
              languagePart.toLowerCase(),
        );
        print(
          '🔄 [STTService] Using available variant: ${matchingLocale.localeId}',
        );
        _locale = matchingLocale.localeId;
        print('✅ [STTService] Successfully set locale to: $_locale');
        return;
      }
    }

    if (!isSupported) {
      print(
        '⚠️ [STTService] Locale $localeId not supported, falling back to en-US',
      );
      _logger.logError(
        'Unsupported locale: $localeId, available: ${supportedLocales.map((l) => l.localeId).join(", ")}',
        context: 'STT',
      );
      // Fall back to English but log the issue
      _locale = 'en-US'; // Use dash format for iOS
      return;
    }

    _locale = localeId;
    print('✅ [STTService] Successfully set locale to: $_locale');
  }

  @override
  Future<List<LocaleName>> getSupportedLocales() async {
    try {
      final locales = await _speech.locales();
      print(
        '📋 [STTService] Available locales: ${locales.map((l) => l.localeId).take(10).join(", ")}...',
      );
      return locales
          .map((e) => LocaleName(localeId: e.localeId, name: e.name))
          .toList();
    } catch (e) {
      print('❌ [STTService] Failed to get supported locales: $e');
      return [];
    }
  }

  @override
  void dispose() {
    print('🗑️ [STTService] Disposing STT service...');

    _finalizationTimer?.cancel();
    _finalizationTimer = null;
    _restartTimer?.cancel();
    _restartTimer = null;
    _currentOnResult = null;
    _currentOnError = null;
    _lastPartialResult = null;

    print('✅ [STTService] STT service disposed');
  }
}
