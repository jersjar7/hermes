// lib/core/hermes_engine/speaker/processors/speech_processor.dart
// Speech-to-text handling and microphone lifecycle

import 'dart:async';

import 'package:hermes/core/hermes_engine/utils/log.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service.dart';
import 'package:hermes/core/services/speech_to_text/speech_result.dart';
import 'package:hermes/core/services/logger/logger_service.dart';

import '../config/speaker_config.dart';

/// Speech processing events
abstract class SpeechProcessingEvent {}

/// Speech result received from STT service
class SpeechResultEvent extends SpeechProcessingEvent {
  final SpeechResult result;
  SpeechResultEvent(this.result);
}

/// Speech processing error occurred
class SpeechErrorEvent extends SpeechProcessingEvent {
  final Exception error;
  SpeechErrorEvent(this.error);
}

/// Speech processing state changed
class SpeechStateChangedEvent extends SpeechProcessingEvent {
  final SpeechProcessingState state;
  SpeechStateChangedEvent(this.state);
}

/// Current state of speech processing
enum SpeechProcessingState {
  /// Not initialized or stopped
  idle,

  /// Starting up speech recognition
  starting,

  /// Actively listening for speech
  listening,

  /// Temporarily paused
  paused,

  /// Stopping speech recognition
  stopping,

  /// Error state
  error,
}

/// Extension methods for SpeechProcessingState
extension SpeechProcessingStateExtension on SpeechProcessingState {
  /// Human-readable description
  String get description {
    switch (this) {
      case SpeechProcessingState.idle:
        return 'Idle';
      case SpeechProcessingState.starting:
        return 'Starting';
      case SpeechProcessingState.listening:
        return 'Listening';
      case SpeechProcessingState.paused:
        return 'Paused';
      case SpeechProcessingState.stopping:
        return 'Stopping';
      case SpeechProcessingState.error:
        return 'Error';
    }
  }

  /// Whether speech processing is active
  bool get isActive => this == SpeechProcessingState.listening;

  /// Whether speech processing can be started
  bool get canStart =>
      this == SpeechProcessingState.idle || this == SpeechProcessingState.error;

  /// Whether speech processing can be stopped
  bool get canStop =>
      this == SpeechProcessingState.listening ||
      this == SpeechProcessingState.paused ||
      this == SpeechProcessingState.starting;

  /// Whether speech processing can be paused
  bool get canPause => this == SpeechProcessingState.listening;

  /// Whether speech processing can be resumed
  bool get canResume => this == SpeechProcessingState.paused;
}

/// Handles speech-to-text processing and microphone lifecycle
class SpeechProcessor {
  /// Speech-to-text service for voice recognition
  final ISpeechToTextService _stt;

  /// Logger for debugging and monitoring
  final HermesLogger _log;

  /// Stream controller for speech processing events
  final StreamController<SpeechProcessingEvent> _eventController =
      StreamController<SpeechProcessingEvent>.broadcast();

  /// Current processing state
  SpeechProcessingState _currentState = SpeechProcessingState.idle;

  /// Target language code for speech recognition
  String? _languageCode;

  /// Last received speech result (for caching/reference)
  SpeechResult? _lastResult;

  /// Error recovery attempt counter
  int _errorRetryCount = 0;

  /// Timer for handling timeouts
  Timer? _timeoutTimer;

  SpeechProcessor({
    required ISpeechToTextService stt,
    required ILoggerService logger,
  }) : _stt = stt,
       _log = HermesLogger(logger, 'SpeechProcessor');

  /// Stream of speech processing events
  Stream<SpeechProcessingEvent> get events => _eventController.stream;

  /// Current processing state
  SpeechProcessingState get currentState => _currentState;

  /// Whether currently listening for speech
  bool get isListening => _currentState.isActive;

  /// Whether speech processor is in error state
  bool get hasError => _currentState == SpeechProcessingState.error;

  /// Last received speech result
  SpeechResult? get lastResult => _lastResult;

  /// Starts speech recognition with specified language
  Future<void> startListening({required String languageCode}) async {
    if (!_currentState.canStart) {
      print(
        '⚠️ [SpeechProcessor] Cannot start - current state: ${_currentState.description}',
      );
      return;
    }

    print(
      '🎤 [SpeechProcessor] Starting speech recognition for language: $languageCode',
    );
    _languageCode = languageCode;
    _errorRetryCount = 0;

    _setState(SpeechProcessingState.starting);

    try {
      await _stt.startListening(
        onResult: _handleSpeechResult,
        onError: _handleSpeechError,
      );

      _setState(SpeechProcessingState.listening);
      print('✅ [SpeechProcessor] Speech recognition started successfully');

      _log.info('Speech recognition started', tag: 'Start');
    } catch (e, stackTrace) {
      print('❌ [SpeechProcessor] Failed to start speech recognition: $e');

      _log.error(
        'Failed to start speech recognition',
        error: e,
        stackTrace: stackTrace,
        tag: 'StartError',
      );

      _setState(SpeechProcessingState.error);
      _emitError(Exception('Failed to start speech recognition: $e'));
    }
  }

  /// Stops speech recognition
  Future<void> stopListening() async {
    if (!_currentState.canStop) {
      print(
        '⚠️ [SpeechProcessor] Cannot stop - current state: ${_currentState.description}',
      );
      return;
    }

    print('🛑 [SpeechProcessor] Stopping speech recognition...');
    _setState(SpeechProcessingState.stopping);

    try {
      await _stt.stopListening();

      // Give STT service time to clean up
      await Future.delayed(SpeakerConfig.sttStopDelay);

      _setState(SpeechProcessingState.idle);
      _clearLastResult();

      print('✅ [SpeechProcessor] Speech recognition stopped successfully');
      _log.info('Speech recognition stopped', tag: 'Stop');
    } catch (e, stackTrace) {
      print('❌ [SpeechProcessor] Error stopping speech recognition: $e');

      _log.error(
        'Error stopping speech recognition',
        error: e,
        stackTrace: stackTrace,
        tag: 'StopError',
      );

      // Force state to idle even if stop failed
      _setState(SpeechProcessingState.idle);
    }
  }

  /// Pauses speech recognition temporarily
  Future<void> pause() async {
    if (!_currentState.canPause) {
      print(
        '⚠️ [SpeechProcessor] Cannot pause - current state: ${_currentState.description}',
      );
      return;
    }

    print('⏸️ [SpeechProcessor] Pausing speech recognition...');

    try {
      await _stt.stopListening();
      _setState(SpeechProcessingState.paused);

      print('✅ [SpeechProcessor] Speech recognition paused');
      _log.info('Speech recognition paused', tag: 'Pause');
    } catch (e, stackTrace) {
      print('❌ [SpeechProcessor] Error pausing speech recognition: $e');

      _log.error(
        'Error pausing speech recognition',
        error: e,
        stackTrace: stackTrace,
        tag: 'PauseError',
      );
    }
  }

  /// Resumes speech recognition from paused state
  Future<void> resume() async {
    if (!_currentState.canResume) {
      print(
        '⚠️ [SpeechProcessor] Cannot resume - current state: ${_currentState.description}',
      );
      return;
    }

    if (_languageCode == null) {
      print('❌ [SpeechProcessor] Cannot resume - no language code set');
      return;
    }

    print('▶️ [SpeechProcessor] Resuming speech recognition...');

    await startListening(languageCode: _languageCode!);
  }

  /// Handles speech recognition results
  void _handleSpeechResult(SpeechResult result) {
    if (!isListening) {
      print('🚫 [SpeechProcessor] Ignoring speech result - not listening');
      return;
    }

    _lastResult = result;

    print(
      '📝 [SpeechProcessor] Speech result: "${result.transcript}" (${result.confidence?.toStringAsFixed(2) ?? 'N/A'} confidence)',
    );

    // Reset error retry count on successful result
    _errorRetryCount = 0;

    // Emit result event
    _emitEvent(SpeechResultEvent(result));

    _log.info(
      'Speech result received: "${result.transcript.substring(0, result.transcript.length.clamp(0, 50))}..." (confidence: ${result.confidence?.toStringAsFixed(2) ?? 'N/A'})',
      tag: 'Result',
    );
  }

  /// Handles speech recognition errors
  void _handleSpeechError(Exception error) {
    print('⚠️ [SpeechProcessor] Speech error: $error');

    if (!isListening && _currentState != SpeechProcessingState.starting) {
      print('🚫 [SpeechProcessor] Ignoring speech error - not in active state');
      return;
    }

    _errorRetryCount++;

    _log.error(
      'Speech recognition error (attempt $_errorRetryCount)',
      error: error,
      tag: 'SpeechError',
    );

    // Attempt automatic recovery for transient errors
    if (_errorRetryCount <= SpeakerConfig.maxProcessingRetries &&
        _languageCode != null) {
      print(
        '🔄 [SpeechProcessor] Attempting error recovery (attempt $_errorRetryCount)...',
      );

      // Brief delay before retry
      Timer(const Duration(seconds: 1), () {
        if (_currentState != SpeechProcessingState.idle) {
          _attemptRecovery();
        }
      });
    } else {
      print(
        '❌ [SpeechProcessor] Max retry attempts reached, entering error state',
      );
      _setState(SpeechProcessingState.error);
    }

    _emitError(error);
  }

  /// Attempts to recover from speech recognition errors
  Future<void> _attemptRecovery() async {
    if (_languageCode == null) return;

    try {
      print('🔧 [SpeechProcessor] Attempting speech recognition recovery...');

      // Stop current session
      await _stt.stopListening();
      await Future.delayed(const Duration(milliseconds: 500));

      // Restart if still in recovery mode
      if (_currentState != SpeechProcessingState.idle) {
        await startListening(languageCode: _languageCode!);
      }
    } catch (e) {
      print('❌ [SpeechProcessor] Recovery failed: $e');
      _setState(SpeechProcessingState.error);
    }
  }

  /// Sets current state and emits state change event
  void _setState(SpeechProcessingState newState) {
    if (_currentState != newState) {
      final previousState = _currentState;
      _currentState = newState;

      print(
        '🔄 [SpeechProcessor] State changed: ${previousState.description} → ${newState.description}',
      );
      _emitEvent(SpeechStateChangedEvent(newState));
    }
  }

  /// Emits a speech processing event
  void _emitEvent(SpeechProcessingEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Emits a speech error event
  void _emitError(Exception error) {
    _emitEvent(SpeechErrorEvent(error));
  }

  /// Clears the last speech result
  void _clearLastResult() {
    _lastResult = null;
  }

  /// Gets current processing statistics
  Map<String, dynamic> getProcessingStats() {
    return {
      'currentState': _currentState.description,
      'isListening': isListening,
      'hasError': hasError,
      'languageCode': _languageCode,
      'errorRetryCount': _errorRetryCount,
      'lastResultLength': _lastResult?.transcript.length ?? 0,
      'lastResultConfidence': _lastResult?.confidence,
    };
  }

  /// Resets error state and retry counter
  void resetErrorState() {
    if (_currentState == SpeechProcessingState.error) {
      print('🔄 [SpeechProcessor] Resetting error state');
      _errorRetryCount = 0;
      _setState(SpeechProcessingState.idle);
    }
  }

  /// Forces the processor to idle state (emergency stop)
  void forceStop() {
    print('🚨 [SpeechProcessor] Force stopping speech processor');

    _timeoutTimer?.cancel();
    _timeoutTimer = null;

    _setState(SpeechProcessingState.idle);
    _clearLastResult();
    _errorRetryCount = 0;

    // Try to stop STT service but don't wait for it
    _stt.stopListening().catchError((e) {
      print('⚠️ [SpeechProcessor] Error in force stop: $e');
    });
  }

  /// Disposes of resources and stops processing
  void dispose() {
    print('🗑️ [SpeechProcessor] Disposing speech processor...');

    _timeoutTimer?.cancel();
    forceStop();

    _stt.dispose();

    if (!_eventController.isClosed) {
      _eventController.close();
    }

    print('✅ [SpeechProcessor] Speech processor disposed');
  }
}
