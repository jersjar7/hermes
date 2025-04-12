// lib/features/translation/infrastructure/services/stt/stt_streaming_manager.dart

import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/audio_stream_handler.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/models/stt_config.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/models/stt_result.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_api_client.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_exceptions.dart';

/// Represents the state of the STT streaming process
enum StreamingState { idle, initializing, streaming, paused, stopping }

/// Manages the streaming of audio for speech-to-text recognition
class SttStreamingManager {
  final Logger _logger;
  final SttApiClient _apiClient;
  final AudioStreamHandler _audioHandler;

  StreamingState _state = StreamingState.idle;
  bool _isRecording = false;
  bool _isPaused = false;
  DateTime? _startTime;

  StreamController<SpeechRecognitionResult>? _resultStreamController;
  StreamSubscription? _recognitionSubscription;

  /// Creates a new [SttStreamingManager]
  SttStreamingManager(this._logger, this._apiClient, this._audioHandler) {
    _startTime = DateTime.now();
  }

  /// Whether streaming is paused
  bool get isPaused => _isPaused;

  /// Current state for debugging
  StreamingState get currentState => _state;

  /// Start streaming audio for transcription
  Stream<SpeechRecognitionResult> startStreaming({
    required String sessionId,
    required String languageCode,
    required bool isInitialized,
    required Future<bool> Function() initFunction,
  }) {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d(
      "[STT_STREAM] [+${elapsed}ms] startStreaming called with languageCode=$languageCode",
    );

    if (_state != StreamingState.idle) {
      _logger.w("[STT_STREAM] startStreaming called but state is $_state");
      return _resultStreamController?.stream ?? const Stream.empty();
    }
    _state = StreamingState.initializing;

    _resultStreamController?.close();
    _recognitionSubscription?.cancel();

    _logger.d(
      "[STT_STREAM] [+${elapsed}ms] Creating new result stream controller",
    );
    _resultStreamController =
        StreamController<SpeechRecognitionResult>.broadcast(
          onListen: () {
            _logger.d("[STT_STREAM] First listener attached to result stream");
          },
          onCancel: () {
            _logger.d(
              "[STT_STREAM] Last listener unsubscribed from result stream",
            );
          },
        );

    _startStreamingProcess(
      sessionId,
      languageCode,
      isInitialized,
      initFunction,
    );

    return _resultStreamController!.stream;
  }

  Future<void> _startStreamingProcess(
    String sessionId,
    String languageCode,
    bool isInitialized,
    Future<bool> Function() initFunction,
  ) async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    try {
      _logger.d("[STT_STREAM] [+${elapsed}ms] Checking microphone permission");
      final permissionStatus = await Permission.microphone.status;

      if (permissionStatus != PermissionStatus.granted) {
        _logger.d("[STT_STREAM] Permission not granted, requesting it");
        final requestResult = await Permission.microphone.request();
        if (requestResult != PermissionStatus.granted) {
          throw MicrophonePermissionException(
            'Microphone permission is required for speech transcription.',
            permissionStatus: requestResult,
          );
        }
      }

      // ADDED: Clear detailed logging here
      _logger.d(
        "[STT_STREAM] [+${elapsed}ms] Permission granted, proceeding with audio setup",
      );

      // Explicitly ensure audio handler is initialized first
      _logger.d(
        "[STT_STREAM] [+${elapsed}ms] Explicitly initializing audio handler",
      );
      final audioInitResult = await _audioHandler.init();
      if (!audioInitResult) {
        throw AudioProcessingException('Failed to initialize audio handler');
      }
      _logger.d(
        "[STT_STREAM] [+${elapsed}ms] Audio handler initialized successfully",
      );

      if (!isInitialized) {
        _logger.d(
          "[STT_STREAM] [+${elapsed}ms] STT service not initialized, initializing now",
        );
        final initialized = await initFunction();
        if (!initialized) {
          throw SttServiceInitializationException(
            'STT Service could not be initialized',
          );
        }
        _logger.d(
          "[STT_STREAM] [+${elapsed}ms] STT service initialized successfully",
        );
      }

      if (_isRecording) {
        _logger.d(
          "[STT_STREAM] [+${elapsed}ms] Already recording, stopping first",
        );
        await stopStreaming();
      }

      final config = SttConfig(
        languageCode: languageCode,
        enableAutomaticPunctuation: true,
        profanityFilter: false,
        interimResults: true,
        sampleRateHertz: 16000,
      );

      _isRecording = true;
      _isPaused = false;
      _state = StreamingState.streaming;

      _logger.d("[STT_STREAM] [+${elapsed}ms] Starting audio streaming");
      final success = await _audioHandler.startStreaming();
      if (!success) {
        throw AudioProcessingException('Failed to start audio streaming');
      }
      _logger.d(
        "[STT_STREAM] [+${elapsed}ms] Audio streaming started successfully",
      );

      _logger.d("[STT_STREAM] [+${elapsed}ms] Creating STT API stream");

      // CHANGED: Add debugging and better error handling
      try {
        final sttStream = _apiClient.streamingRecognize(
          audioStream: _audioHandler.audioStream,
          config: config,
        );

        _logger.d(
          "[STT_STREAM] [+${elapsed}ms] STT API stream created successfully",
        );

        _recognitionSubscription = sttStream.listen(
          (result) {
            final listenElapsed =
                _startTime != null
                    ? DateTime.now().difference(_startTime!).inMilliseconds
                    : 0;
            _logger.d(
              "[STT_STREAM] [+${listenElapsed}ms] Received STT result: '${result.transcript}' (final: ${result.isFinal})",
            );

            // FIX: Add proper null, closure and listener check
            if (_resultStreamController != null &&
                !_resultStreamController!.isClosed &&
                _resultStreamController!.hasListener) {
              _resultStreamController!.add(result);
            }
          },
          onError: (error) {
            final listenElapsed =
                _startTime != null
                    ? DateTime.now().difference(_startTime!).inMilliseconds
                    : 0;
            _logger.e(
              '[STT_STREAM] [+${listenElapsed}ms] Error in STT API stream',
              error: error,
            );

            // ADDED: More detailed error logging
            _logger.e('[STT_STREAM] Error details', error: error.toString());

            // FIX: Add proper null, closure and listener check
            if (_resultStreamController != null &&
                !_resultStreamController!.isClosed &&
                _resultStreamController!.hasListener) {
              _resultStreamController!.addError(error);
            }
          },
          onDone: () {
            // ADDED: More context about why the stream closed
            _logger.d(
              '[STT_STREAM] STT API stream closed, checking if this is expected',
            );
            if (_state == StreamingState.stopping) {
              _logger.d(
                '[STT_STREAM] Stream closed as expected during stopStreaming()',
              );
            } else {
              _logger.e(
                '[STT_STREAM] Stream closed unexpectedly! Current state: $_state',
              );
            }
          },
          // ADDED: Don't cancel on error to allow recovery
          cancelOnError: false,
        );

        _logger.d(
          "[STT_STREAM] [+${elapsed}ms] STT recognition subscription set up successfully",
        );
      } catch (apiError) {
        // ADDED: Specific error handling for API stream creation
        _logger.e(
          '[STT_STREAM] Failed to create STT API stream',
          error: apiError,
        );
        throw AudioProcessingException(
          'Failed to create speech recognition stream: ${apiError.toString()}',
        );
      }
    } catch (e, stacktrace) {
      _logger.e(
        '[STT_STREAM] Error starting STT process',
        error: e,
        stackTrace: stacktrace,
      );

      // FIX: Add proper null and closure check
      if (_resultStreamController != null &&
          !_resultStreamController!.isClosed) {
        _resultStreamController!.addError(
          e is Exception ? e : Exception('Error: $e'),
        );
      }

      _state = StreamingState.idle;
      await stopStreaming();
    }
  }

  /// Stop streaming audio
  Future<void> stopStreaming() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d(
      "[STT_STREAM] [+${elapsed}ms] stopStreaming called, _isRecording=$_isRecording",
    );

    if (!_isRecording) {
      _logger.d("[STT_STREAM] [+${elapsed}ms] Not recording, nothing to stop");
      return;
    }

    try {
      // Stop audio streaming
      if (_audioHandler.isStreaming) {
        _logger.d("[STT_STREAM] [+${elapsed}ms] Stopping audio handler");
        await _audioHandler.stopStreaming();
        _logger.d("[STT_STREAM] [+${elapsed}ms] Audio handler stopped");
      }

      // Cancel STT recognition stream subscription
      if (_recognitionSubscription != null) {
        _logger.d(
          "[STT_STREAM] [+${elapsed}ms] Cancelling recognition subscription",
        );
        await _recognitionSubscription!.cancel();
        _recognitionSubscription = null;
        _logger.d(
          "[STT_STREAM] [+${elapsed}ms] Recognition subscription cancelled",
        );
      }

      // Close result stream controller if open
      if (_resultStreamController != null) {
        try {
          if (!_resultStreamController!.isClosed) {
            _logger.d(
              "[STT_STREAM] [+${elapsed}ms] Closing result stream controller",
            );
            await _resultStreamController!.close();
          }
        } catch (e) {
          _logger.e("[STT_STREAM] Error closing stream controller", error: e);
        } finally {
          _resultStreamController = null;
        }
      }

      _isRecording = false;
      _isPaused = false;
      _state = StreamingState.idle;

      _logger.d("[STT_STREAM] [+${elapsed}ms] Streaming stopped successfully");
    } catch (e, stacktrace) {
      _logger.e(
        '[STT_STREAM] [+${elapsed}ms] Error stopping STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
    }
  }

  Future<void> pauseStreaming() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    if (!_isRecording || _isPaused || _state != StreamingState.streaming)
      return;

    try {
      await _audioHandler.pauseStreaming();
      _isPaused = true;
      _state = StreamingState.paused;
      _logger.d("[STT_STREAM] [+${elapsed}ms] Audio streaming paused");
    } catch (e, stacktrace) {
      _logger.e(
        '[STT_STREAM] Error pausing STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
    }
  }

  Future<void> resumeStreaming() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    if (!_isRecording || !_isPaused || _state != StreamingState.paused) return;

    try {
      await _audioHandler.resumeStreaming();
      _isPaused = false;
      _state = StreamingState.streaming;
      _logger.d("[STT_STREAM] [+${elapsed}ms] Audio streaming resumed");
    } catch (e, stacktrace) {
      _logger.e(
        '[STT_STREAM] Error resuming STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
    }
  }
}
