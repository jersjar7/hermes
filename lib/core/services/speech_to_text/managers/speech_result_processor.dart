// lib/core/services/speech_to_text/managers/speech_result_processor.dart

import 'dart:async';
import 'package:speech_to_text/speech_recognition_result.dart' as stt;
import '../speech_result.dart';
import 'speech_session_manager.dart';
import 'speech_restart_manager.dart';

/// Processes speech recognition results and handles finalization logic.
/// Manages partial results, final results, and status changes.
class SpeechResultProcessor {
  final SpeechRestartManager _restartManager;

  SpeechSessionManager? _sessionManager;
  String _locale = 'en-US';

  Timer? _finalizationTimer;
  bool _wasListening = false;

  static const Duration _finalizationTimeout = Duration(seconds: 2);

  SpeechResultProcessor(this._restartManager);

  /// Configures the result processor with dependencies
  void configure({
    required SpeechSessionManager sessionManager,
    required String locale,
  }) {
    _sessionManager = sessionManager;
    _locale = locale;
  }

  /// Handles speech recognition results from the platform
  void handleResult({
    required stt.SpeechRecognitionResult result,
    required void Function({Duration? customDelay}) onRestart,
  }) {
    if (_sessionManager?.shouldProcessResults() != true) {
      print('🚫 [ResultProcessor] Ignoring result - session not active');
      return;
    }

    final transcript = result.recognizedWords.trim();
    final isFinal = result.finalResult;

    print(
      '📝 [ResultProcessor] Result: "$transcript" (final: $isFinal, confidence: ${result.confidence})',
    );

    if (transcript.isNotEmpty) {
      if (isFinal) {
        _handleFinalResult(transcript, onRestart);
      } else {
        _handlePartialResult(transcript);
      }
    }
  }

  /// Handles status changes from the speech recognition service
  void handleStatusChange({
    required String status,
    required void Function({Duration? customDelay}) onRestart,
  }) {
    final currentlyListening = status == 'listening';

    // Handle status transitions
    if ((status == 'notListening' || status == 'done') && _wasListening) {
      print('📊 [ResultProcessor] Status transition: listening -> $status');

      // Finalize any partial results
      _handlePotentialFinalization();

      // Schedule restart if session is still active
      if (_sessionManager?.isActive == true) {
        print('🔄 [ResultProcessor] Scheduling restart after status change');
        onRestart();
      }
    } else if (currentlyListening && !_wasListening) {
      print('📊 [ResultProcessor] Status transition: -> listening');
      // Reset finalization timer when we start listening
      _finalizationTimer?.cancel();
    }

    _wasListening = currentlyListening;
  }

  void _handleFinalResult(
    String transcript,
    void Function({Duration? customDelay}) onRestart,
  ) {
    print('✅ [ResultProcessor] Processing final result: "$transcript"');

    // Clear finalization timer and partial result
    _finalizationTimer?.cancel();
    _finalizationTimer = null;

    // Create and emit final result
    final speechResult = SpeechResult(
      transcript: transcript,
      isFinal: true,
      timestamp: DateTime.now(),
      locale: _locale,
    );

    _sessionManager?.emitResult(speechResult);

    // Schedule restart with longer delay after final result
    print('🔄 [ResultProcessor] Scheduling restart after final result');
    final delay = _restartManager.getFinalResultDelay();
    onRestart(customDelay: delay);
  }

  void _handlePartialResult(String transcript) {
    print('📝 [ResultProcessor] Processing partial result: "$transcript"');

    // Update session manager with partial result
    _sessionManager?.updatePartialResult(transcript);

    // Create and emit partial result
    final speechResult = SpeechResult(
      transcript: transcript,
      isFinal: false,
      timestamp: DateTime.now(),
      locale: _locale,
    );

    _sessionManager?.emitResult(speechResult);

    // Start/restart finalization timer
    _startFinalizationTimer();
  }

  void _startFinalizationTimer() {
    _finalizationTimer?.cancel();
    _finalizationTimer = Timer(_finalizationTimeout, () {
      print('⏰ [ResultProcessor] Finalization timeout reached');
      _handlePotentialFinalization();
    });
  }

  void _handlePotentialFinalization() {
    final partialResult = _sessionManager?.lastPartialResult;

    if (partialResult != null &&
        partialResult.isNotEmpty &&
        _sessionManager?.shouldProcessResults() == true) {
      print('⏰ [ResultProcessor] Finalizing partial result: "$partialResult"');

      final finalResult = SpeechResult(
        transcript: partialResult,
        isFinal: true,
        timestamp: DateTime.now(),
        locale: _locale,
      );

      _sessionManager?.emitResult(finalResult);
    }

    _finalizationTimer?.cancel();
    _finalizationTimer = null;
  }

  /// Cancels any pending finalization
  void cancelFinalization() {
    _finalizationTimer?.cancel();
    _finalizationTimer = null;
  }

  /// Gets result processor status for debugging
  String getStatus() {
    return 'ResultProcessor(hasTimer: ${_finalizationTimer != null}, '
        'wasListening: $_wasListening, locale: $_locale)';
  }

  void dispose() {
    print('🗑️ [ResultProcessor] Disposing');
    _finalizationTimer?.cancel();
    _finalizationTimer = null;
    _sessionManager = null;
    _wasListening = false;
  }
}
