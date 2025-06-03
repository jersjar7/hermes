// lib/core/services/speech_to_text/speech_to_text_service_impl.dart

import 'dart:async';
import 'package:speech_to_text/speech_recognition_error.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../logger/logger_service.dart';
import 'speech_to_text_service.dart';
import 'speech_result.dart';
import 'managers/speech_session_manager.dart';
import 'managers/speech_restart_manager.dart';
import 'managers/speech_error_handler.dart';
import 'managers/speech_result_processor.dart';

/// Main speech-to-text service implementation.
/// Delegates specific responsibilities to focused managers.
class SpeechToTextServiceImpl implements ISpeechToTextService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  final ILoggerService _logger;

  // Focused managers for different responsibilities
  late final SpeechSessionManager _sessionManager;
  late final SpeechRestartManager _restartManager;
  late final SpeechErrorHandler _errorHandler;
  late final SpeechResultProcessor _resultProcessor;

  bool _isAvailable = false;
  String _locale = 'en-US';

  SpeechToTextServiceImpl(this._logger) {
    // Initialize managers with dependencies
    _sessionManager = SpeechSessionManager(_logger);
    _restartManager = SpeechRestartManager(_logger);
    _errorHandler = SpeechErrorHandler(_logger, _restartManager);
    _resultProcessor = SpeechResultProcessor(_restartManager);
  }

  @override
  Future<bool> initialize() async {
    print('🎙️ [STTService] Initializing speech-to-text service...');

    try {
      _isAvailable = await _speech.initialize(
        onStatus: _handleStatusChange,
        onError: _handleError,
        debugLogging: false,
      );

      print('📱 [STTService] Initialization result: $_isAvailable');

      if (_isAvailable) {
        final locales = await _speech.locales();
        print('🌍 [STTService] Available locales: ${locales.length}');
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

    print('🎤 [STTService] Starting listening with locale: $_locale');

    // Start session through session manager
    _sessionManager.startSession(onResult, onError);

    // Configure other managers
    _resultProcessor.configure(
      sessionManager: _sessionManager,
      locale: _locale,
    );

    _errorHandler.configure(
      sessionManager: _sessionManager,
      onStartListening: _startListeningInternal,
    );

    await _startListeningInternal();
  }

  Future<void> _startListeningInternal() async {
    // Check if session is still active
    if (!_sessionManager.isActive) {
      print('🚫 [STTService] Session no longer active, aborting start');
      return;
    }

    // Wait for restart manager if needed
    await _restartManager.waitForNextStart();

    // Check again after delay
    if (!_sessionManager.isActive) {
      print('🚫 [STTService] Session cancelled during delay, aborting start');
      return;
    }

    try {
      // Ensure we're not already listening
      if (_speech.isListening) {
        print('⚠️ [STTService] Already listening, stopping first...');
        await _speech.stop();
        await _restartManager.waitAfterStop();
      }

      await _speech.listen(
        localeId: _locale,
        onResult: _handleSpeechResult,
        cancelOnError: false,
        partialResults: true,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 5),
      );

      print('✅ [STTService] Listening started successfully');
      _errorHandler.resetErrorCount();
    } catch (e) {
      print('❌ [STTService] Start listening failed: $e');
      _errorHandler.handleStartError();
    }
  }

  void _handleStatusChange(String status) {
    print('🎙️ [STTService] Status: $status');
    _logger.logInfo('STT status: $status', context: 'STT');

    // Let result processor handle status changes
    _resultProcessor.handleStatusChange(
      status: status,
      onRestart: _scheduleRestart,
    );
  }

  void _handleError(stt.SpeechRecognitionError error) {
    print('❌ [STTService] Error: $error');
    _logger.logError('STT error: $error', context: 'STT');

    // Delegate to error handler
    _errorHandler.handleSpeechError(error);
  }

  void _handleSpeechResult(stt.SpeechRecognitionResult result) {
    // Delegate to result processor
    _resultProcessor.handleResult(result: result, onRestart: _scheduleRestart);
  }

  void _scheduleRestart({Duration? customDelay}) {
    if (!_sessionManager.isActive) {
      print('🚫 [STTService] No active session, skipping restart');
      return;
    }

    _restartManager.scheduleRestart(
      customDelay: customDelay,
      onRestart: _startListeningInternal,
    );
  }

  @override
  Future<void> stopListening() async {
    print('🛑 [STTService] Stopping listening...');

    // Stop session through session manager (this handles final result emission)
    await _sessionManager.stopSession();

    // Cancel restart manager
    _restartManager.cancelRestart();

    // Stop speech service
    try {
      if (_speech.isListening) {
        await _speech.stop();
        await _restartManager.waitAfterStop();
      }
      print('✅ [STTService] Speech service stopped');
    } catch (e) {
      print('⚠️ [STTService] Error stopping speech service: $e');
    }

    print('✅ [STTService] Listening stopped completely');
  }

  @override
  Future<void> cancel() async {
    print('❌ [STTService] Cancelling listening...');

    // Cancel everything immediately
    _sessionManager.cancelSession();
    _restartManager.cancelRestart();

    try {
      await _speech.cancel();
      await _restartManager.waitAfterStop();
      print('✅ [STTService] Speech service cancelled');
    } catch (e) {
      print('⚠️ [STTService] Error cancelling speech service: $e');
    }

    print('✅ [STTService] Listening cancelled completely');
  }

  @override
  bool get isAvailable => _isAvailable;

  @override
  bool get isListening => _speech.isListening;

  @override
  Future<bool> get hasPermission async => _isAvailable;

  @override
  Future<void> setLocale(String localeId) async {
    print('🌍 [STTService] Setting locale to: $localeId');

    final supportedLocales = await getSupportedLocales();

    // Try exact match first
    bool isSupported = supportedLocales.any(
      (locale) => locale.localeId.toLowerCase() == localeId.toLowerCase(),
    );

    if (!isSupported) {
      // Try alternate format (dash <-> underscore)
      final alternateFormat =
          localeId.contains('-')
              ? localeId.replaceAll('-', '_')
              : localeId.replaceAll('_', '-');

      isSupported = supportedLocales.any(
        (locale) =>
            locale.localeId.toLowerCase() == alternateFormat.toLowerCase(),
      );

      if (isSupported) {
        _locale = alternateFormat;
        print('✅ [STTService] Using alternate format: $alternateFormat');
        return;
      }
    }

    if (!isSupported) {
      // Try language part only
      final languagePart = localeId.split(RegExp(r'[-_]'))[0];
      final matchingLocale = supportedLocales.cast<LocaleName?>().firstWhere(
        (locale) =>
            locale!.localeId.split(RegExp(r'[-_]'))[0].toLowerCase() ==
            languagePart.toLowerCase(),
        orElse: () => null,
      );

      if (matchingLocale != null) {
        _locale = matchingLocale.localeId;
        print('✅ [STTService] Using variant: ${matchingLocale.localeId}');
        return;
      }

      print('⚠️ [STTService] Locale $localeId not supported, using en-US');
      _locale = 'en-US';
      return;
    }

    _locale = localeId;
    print('✅ [STTService] Locale set to: $_locale');
  }

  @override
  Future<List<LocaleName>> getSupportedLocales() async {
    try {
      final locales = await _speech.locales();
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

    _sessionManager.dispose();
    _restartManager.dispose();
    _resultProcessor.dispose();
    _errorHandler.dispose();

    print('✅ [STTService] STT service disposed');
  }
}
