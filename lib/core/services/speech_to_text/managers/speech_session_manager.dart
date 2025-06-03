// lib/core/services/speech_to_text/managers/speech_session_manager.dart

import 'package:hermes/core/services/logger/logger_service.dart';

import '../speech_result.dart';

/// Manages the lifecycle and state of a speech recognition session.
/// Handles callbacks, session state, and cleanup.
class SpeechSessionManager {
  final ILoggerService _logger;

  // Session state
  bool _isActive = false;
  void Function(SpeechResult)? _onResult;
  void Function(Exception)? _onError;
  String? _lastPartialResult;

  SpeechSessionManager(this._logger);

  /// Whether the session is currently active
  bool get isActive => _isActive;

  /// Whether we have callbacks set up
  bool get hasCallbacks => _onResult != null && _onError != null;

  /// Get the last partial result
  String? get lastPartialResult => _lastPartialResult;

  /// Starts a new speech recognition session
  void startSession(
    void Function(SpeechResult) onResult,
    void Function(Exception) onError,
  ) {
    print('📱 [SessionManager] Starting new session');

    _isActive = true;
    _onResult = onResult;
    _onError = onError;
    _lastPartialResult = null;

    _logger.logInfo('Speech session started', context: 'SessionManager');
  }

  /// Emits a speech result if session is active
  void emitResult(SpeechResult result) {
    if (!_isActive || _onResult == null) {
      print('🚫 [SessionManager] Cannot emit result - session inactive');
      return;
    }

    print(
      '📝 [SessionManager] Emitting result: "${result.transcript}" (final: ${result.isFinal})',
    );

    if (result.isFinal) {
      _lastPartialResult = null; // Clear on final result
    } else {
      _lastPartialResult = result.transcript; // Store partial result
    }

    _onResult!(result);
  }

  /// Emits an error if session is active
  void emitError(Exception error) {
    if (!_isActive || _onError == null) {
      print('🚫 [SessionManager] Cannot emit error - session inactive');
      return;
    }

    print('❌ [SessionManager] Emitting error: $error');
    _onError!(error);
  }

  /// Updates the last partial result
  void updatePartialResult(String transcript) {
    if (_isActive) {
      _lastPartialResult = transcript;
    }
  }

  /// Stops the session and returns any final result that should be emitted
  Future<({SpeechResult? result, void Function(SpeechResult)? callback})?>
  stopSession() async {
    print('🛑 [SessionManager] Stopping session');

    if (!_isActive) {
      print('⚠️ [SessionManager] Session already inactive');
      return null;
    }

    // Capture final state before clearing
    final finalCallback = _onResult;
    final finalPartialResult = _lastPartialResult;

    // Mark session as inactive
    _isActive = false;

    // Clear callbacks
    _onResult = null;
    _onError = null;

    // Create final result if we have partial text
    if (finalPartialResult != null &&
        finalPartialResult.isNotEmpty &&
        finalCallback != null) {
      final finalResult = SpeechResult(
        transcript: finalPartialResult,
        isFinal: true,
        timestamp: DateTime.now(),
        locale: 'en-US', // This should be passed in, but keeping simple for now
      );

      print(
        '📤 [SessionManager] Preparing final result: "$finalPartialResult"',
      );

      // Return both the result and callback so caller can emit it
      return (result: finalResult, callback: finalCallback);
    }

    _lastPartialResult = null;
    _logger.logInfo('Speech session stopped', context: 'SessionManager');
    return null;
  }

  /// Cancels the session immediately without emitting final results
  void cancelSession() {
    print('❌ [SessionManager] Cancelling session');

    _isActive = false;
    _onResult = null;
    _onError = null;
    _lastPartialResult = null;

    _logger.logInfo('Speech session cancelled', context: 'SessionManager');
  }

  /// Checks if we should process results (session active and has callbacks)
  bool shouldProcessResults() {
    return _isActive && _onResult != null;
  }

  /// Gets session info for debugging
  String getSessionInfo() {
    return 'Session(active: $_isActive, hasCallbacks: $hasCallbacks, '
        'hasPartial: ${_lastPartialResult != null})';
  }

  void dispose() {
    print('🗑️ [SessionManager] Disposing');
    cancelSession();
  }
}
