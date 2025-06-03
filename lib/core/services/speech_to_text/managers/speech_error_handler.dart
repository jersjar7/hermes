// lib/core/services/speech_to_text/managers/speech_error_handler.dart

import 'dart:io';
import 'package:hermes/core/services/logger/logger_service.dart';
import 'package:speech_to_text/speech_recognition_error.dart' as stt;
import 'speech_session_manager.dart';
import 'speech_restart_manager.dart';

/// Handles different types of speech recognition errors and recovery strategies.
/// Implements error-specific backoff and retry logic.
class SpeechErrorHandler {
  final ILoggerService _logger;
  final SpeechRestartManager _restartManager;

  SpeechSessionManager? _sessionManager;
  Future<void> Function()? _onStartListening;

  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 5;

  SpeechErrorHandler(this._logger, this._restartManager);

  /// Configures the error handler with dependencies
  void configure({
    required SpeechSessionManager sessionManager,
    required Future<void> Function() onStartListening,
  }) {
    _sessionManager = sessionManager;
    _onStartListening = onStartListening;
  }

  /// Resets the consecutive error counter
  void resetErrorCount() {
    if (_consecutiveErrors > 0) {
      print('✅ [ErrorHandler] Reset error count (was $_consecutiveErrors)');
      _consecutiveErrors = 0;
    }
  }

  /// Handles errors that occur during startListening()
  void handleStartError() {
    _consecutiveErrors++;
    print('❌ [ErrorHandler] Start error (count: $_consecutiveErrors)');

    if (_shouldStopSession()) {
      _stopSessionDueToErrors();
      return;
    }

    // Schedule restart with backoff delay
    final delay = _restartManager.getErrorBackoffDelay(_consecutiveErrors);
    _scheduleRestart(customDelay: delay);
  }

  /// Handles speech recognition errors from the platform
  void handleSpeechError(stt.SpeechRecognitionError error) {
    if (_sessionManager?.isActive != true) {
      print('🚫 [ErrorHandler] Ignoring error - session not active');
      return;
    }

    print('🔧 [ErrorHandler] Handling error: ${error.errorMsg}');
    _consecutiveErrors++;

    // Check if we should stop the session
    if (_shouldStopSession() || _isPermanentError(error)) {
      _stopSessionDueToErrors();
      return;
    }

    // Handle specific error types
    _handleSpecificError(error);
  }

  void _handleSpecificError(stt.SpeechRecognitionError error) {
    final errorType = error.errorMsg;

    switch (errorType) {
      case 'error_busy':
        _handleBusyError();
        break;
      case 'error_no_match':
        _handleNoMatchError();
        break;
      case 'error_speech_timeout':
        _handleTimeoutError();
        break;
      case 'error_audio':
        _handleAudioError();
        break;
      case 'error_network':
        _handleNetworkError();
        break;
      default:
        _handleUnknownError(errorType, error.permanent);
        break;
    }
  }

  void _handleBusyError() {
    print('🤖 [ErrorHandler] Speech service busy - waiting longer');
    final delay = Duration(seconds: _consecutiveErrors * 2);
    _scheduleRestart(customDelay: delay);
  }

  void _handleNoMatchError() {
    print('🔄 [ErrorHandler] No speech detected');
    if (Platform.isAndroid) {
      // Android often reports no_match normally
      final delay = _restartManager.getErrorTypeDelay('error_no_match');
      _scheduleRestart(customDelay: delay);
    } else {
      _scheduleRestart();
    }
  }

  void _handleTimeoutError() {
    print('⏰ [ErrorHandler] Speech timeout - restarting');
    final delay = _restartManager.getErrorTypeDelay('error_speech_timeout');
    _scheduleRestart(customDelay: delay);
  }

  void _handleAudioError() {
    print('🎵 [ErrorHandler] Audio error - checking microphone');
    final delay = _restartManager.getErrorTypeDelay('error_audio');
    _scheduleRestart(customDelay: delay);
  }

  void _handleNetworkError() {
    print('🌐 [ErrorHandler] Network error - retrying');

    // Emit error to user for network issues
    _sessionManager?.emitError(Exception('Network error, retrying...'));

    final delay = _restartManager.getErrorTypeDelay('error_network');
    _scheduleRestart(customDelay: delay);
  }

  void _handleUnknownError(String errorType, bool isPermanent) {
    print(
      '❓ [ErrorHandler] Unknown error: $errorType (permanent: $isPermanent)',
    );

    if (isPermanent) {
      _sessionManager?.emitError(
        Exception('Speech recognition error: $errorType'),
      );
      _stopSessionDueToErrors();
    } else {
      final delay = _restartManager.getErrorTypeDelay('default');
      _scheduleRestart(customDelay: delay);
    }
  }

  void _scheduleRestart({Duration? customDelay}) {
    if (_sessionManager?.isActive != true || _onStartListening == null) {
      print('🚫 [ErrorHandler] Cannot restart - session inactive');
      return;
    }

    _restartManager.scheduleRestart(
      customDelay: customDelay,
      onRestart: _onStartListening!,
    );
  }

  bool _shouldStopSession() {
    return _consecutiveErrors >= _maxConsecutiveErrors;
  }

  bool _isPermanentError(stt.SpeechRecognitionError error) {
    // Some errors are always permanent regardless of the flag
    const permanentErrors = {
      'error_insufficient_permissions',
      'error_recognizer_busy', // Different from error_busy
      'error_client',
    };

    return error.permanent || permanentErrors.contains(error.errorMsg);
  }

  void _stopSessionDueToErrors() {
    print(
      '🚫 [ErrorHandler] Stopping session due to errors (count: $_consecutiveErrors)',
    );

    final errorMessage =
        _consecutiveErrors >= _maxConsecutiveErrors
            ? 'Speech recognition failed after multiple attempts. Please try again.'
            : 'Speech recognition error occurred. Please try again.';

    _sessionManager?.emitError(Exception(errorMessage));
    _sessionManager?.cancelSession();

    _logger.logError(
      'Session stopped due to consecutive errors',
      context: 'ErrorHandler',
    );
  }

  /// Gets error handler status for debugging
  String getStatus() {
    return 'ErrorHandler(errors: $_consecutiveErrors/$_maxConsecutiveErrors, '
        'configured: ${_sessionManager != null})';
  }

  void dispose() {
    print('🗑️ [ErrorHandler] Disposing');
    _sessionManager = null;
    _onStartListening = null;
    _consecutiveErrors = 0;
  }
}
