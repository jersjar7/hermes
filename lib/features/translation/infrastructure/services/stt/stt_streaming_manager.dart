// lib/features/translation/infrastructure/services/stt/stt_streaming_manager.dart

import 'dart:async';
import 'dart:convert';

import 'package:permission_handler/permission_handler.dart';

import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/audio_stream_handler.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/models/stt_config.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/models/stt_result.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_api_client.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_exceptions.dart';

/// Manages the streaming of audio for speech-to-text recognition
class SttStreamingManager {
  final Logger _logger;
  final SttApiClient _apiClient;
  final AudioStreamHandler _audioHandler;

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

  /// Start streaming audio for transcription
  ///
  /// Returns a stream of transcription results
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

    // Close existing stream if any
    _resultStreamController?.close();
    _recognitionSubscription?.cancel();

    // Create a new stream controller
    _logger.d(
      "[STT_STREAM] [+${elapsed}ms] Creating new result stream controller",
    );
    _resultStreamController =
        StreamController<SpeechRecognitionResult>.broadcast(
          // Add lifecycle callbacks for better debugging
          onListen: () {
            _logger.d("[STT_STREAM] First listener attached to result stream");
          },
          onCancel: () {
            _logger.d(
              "[STT_STREAM] Last listener unsubscribed from result stream",
            );
          },
        );

    // Start the streaming process asynchronously
    _startStreamingProcess(
      sessionId,
      languageCode,
      isInitialized,
      initFunction,
    );

    // Return the stream immediately
    return _resultStreamController!.stream;
  }

  /// Internal method to start the streaming process
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
      // Check permissions first
      _logger.d("[STT_STREAM] [+${elapsed}ms] Checking microphone permission");
      final permissionStatus = await Permission.microphone.status;
      _logger.d(
        "[STT_STREAM] [+${elapsed}ms] Microphone permission status: $permissionStatus",
      );

      if (permissionStatus != PermissionStatus.granted) {
        _logger.d("[STT_STREAM] [+${elapsed}ms] Permission not granted");

        final requestResult = await Permission.microphone.request();
        _logger.d(
          "[STT_STREAM] [+${elapsed}ms] Permission request result: $requestResult",
        );

        if (requestResult != PermissionStatus.granted) {
          throw MicrophonePermissionException(
            'Microphone permission is required for speech transcription.',
            permissionStatus: requestResult,
          );
        }
      }

      // After permission check and before initializing:
      _logger.d(
        "[STT_STREAM] [+${elapsed}ms] Starting audio with following parameters:",
      );
      _logger.d("[STT_STREAM] [+${elapsed}ms] Session ID: $sessionId");
      _logger.d("[STT_STREAM] [+${elapsed}ms] Language code: $languageCode");
      _logger.d(
        "[STT_STREAM] [+${elapsed}ms] STT API URL: https://speech.googleapis.com/v1p1beta1/speech:streamingRecognize",
      );

      // Initialize if needed
      if (!isInitialized) {
        _logger.d(
          "[STT_STREAM] [+${elapsed}ms] Not initialized, calling init()",
        );
        final initialized = await initFunction();
        if (!initialized) {
          throw SttServiceInitializationException(
            'STT Service could not be initialized',
          );
        }
      }

      // Stop any existing recording
      if (_isRecording) {
        _logger.d(
          "[STT_STREAM] [+${elapsed}ms] Already recording, stopping first",
        );
        await stopStreaming();
      }

      // Create STT config
      final config = SttConfig(
        languageCode: languageCode,
        enableAutomaticPunctuation: true,
        profanityFilter: false,
        interimResults: true,
        sampleRateHertz: 16000,
      );

      // After creating SttConfig:
      _logger.d(
        "[STT_STREAM] [+${elapsed}ms] STT Streaming Config: ${jsonEncode(config.toStreamingConfig())}",
      );

      // Start audio recording
      _isRecording = true;
      _isPaused = false;

      _logger.d("[STT_STREAM] [+${elapsed}ms] Using real microphone input");

      // Start audio handler and get audio stream
      _logger.d("[STT_STREAM] [+${elapsed}ms] Starting audio streaming");
      final success = await _audioHandler.startStreaming();

      if (!success) {
        throw AudioProcessingException('Failed to start audio streaming');
      }

      _logger.d(
        "[STT_STREAM] [+${elapsed}ms] Audio streaming started successfully",
      );

      // Connect audio stream to STT API
      _logger.d(
        "[STT_STREAM] [+${elapsed}ms] Connecting audio stream to STT API",
      );
      final sttStream = _apiClient.streamingRecognize(
        audioStream: _audioHandler.audioStream,
        config: config,
      );

      _logger.d("[STT_STREAM] [+${elapsed}ms] STT API stream established");

      // Forward results to our stream controller
      _recognitionSubscription = sttStream.listen(
        (result) {
          final listenElapsed =
              _startTime != null
                  ? DateTime.now().difference(_startTime!).inMilliseconds
                  : 0;

          _logger.d(
            "[STT_STREAM] [+${listenElapsed}ms] Received STT result: '${result.transcript}' (final: ${result.isFinal})",
          );

          if (!_resultStreamController!.isClosed) {
            _resultStreamController!.add(result);
          } else {
            _logger.d(
              "[STT_STREAM] [+${listenElapsed}ms] Stream controller closed, discarding result",
            );
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

          if (!_resultStreamController!.isClosed) {
            _resultStreamController!.addError(error);
          }
        },
        onDone: () {
          final listenElapsed =
              _startTime != null
                  ? DateTime.now().difference(_startTime!).inMilliseconds
                  : 0;

          _logger.d('[STT_STREAM] [+${listenElapsed}ms] STT API stream closed');
          // Don't close the controller here, as we might want to restart streaming
        },
      );

      _logger.d(
        "[STT_STREAM] [+${elapsed}ms] Successfully set up transcription pipeline",
      );
    } catch (e, stacktrace) {
      final catchElapsed =
          _startTime != null
              ? DateTime.now().difference(_startTime!).inMilliseconds
              : 0;

      _logger.e(
        '[STT_STREAM] [+${catchElapsed}ms] Error starting STT process',
        error: e,
        stackTrace: stacktrace,
      );

      if (!_resultStreamController!.isClosed) {
        if (e is MicrophonePermissionException) {
          _resultStreamController!.addError(e);
        } else {
          _resultStreamController!.addError(
            e is Exception ? e : Exception('Error starting STT process: $e'),
          );
        }
      }

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

    if (!_isRecording) return;

    try {
      // Stop audio handling
      _logger.d("[STT_STREAM] [+${elapsed}ms] Stopping audio handler");
      await _audioHandler.stopStreaming();
      _logger.d("[STT_STREAM] [+${elapsed}ms] Audio handler stopped");

      // Cancel recognition subscription
      _logger.d(
        "[STT_STREAM] [+${elapsed}ms] Cancelling recognition subscription",
      );
      await _recognitionSubscription?.cancel();
      _recognitionSubscription = null;
      _logger.d(
        "[STT_STREAM] [+${elapsed}ms] Recognition subscription cancelled",
      );

      _isRecording = false;
      _isPaused = false;

      // Close the result stream controller
      _logger.d(
        "[STT_STREAM] [+${elapsed}ms] Closing result stream controller",
      );
      await _resultStreamController?.close();
      _resultStreamController = null;

      _logger.d("[STT_STREAM] [+${elapsed}ms] Streaming stopped successfully");
    } catch (e, stacktrace) {
      _logger.e(
        '[STT_STREAM] [+${elapsed}ms] Error stopping STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
    }
  }

  /// Pause streaming audio
  Future<void> pauseStreaming() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d(
      "[STT_STREAM] [+${elapsed}ms] pauseStreaming called, _isRecording=$_isRecording",
    );

    if (!_isRecording || _isPaused) return;

    try {
      _logger.d("[STT_STREAM] [+${elapsed}ms] Pausing audio handler");
      await _audioHandler.pauseStreaming();
      _isPaused = true;
      _logger.d("[STT_STREAM] [+${elapsed}ms] Audio streaming paused");
    } catch (e, stacktrace) {
      _logger.e(
        '[STT_STREAM] [+${elapsed}ms] Error pausing STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
    }
  }

  /// Resume streaming audio
  Future<void> resumeStreaming() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d(
      "[STT_STREAM] [+${elapsed}ms] resumeStreaming called, _isRecording=$_isRecording, _isPaused=$_isPaused",
    );

    if (!_isRecording || !_isPaused) return;

    try {
      _logger.d("[STT_STREAM] [+${elapsed}ms] Resuming audio handler");
      await _audioHandler.resumeStreaming();
      _isPaused = false;
      _logger.d("[STT_STREAM] [+${elapsed}ms] Audio streaming resumed");
    } catch (e, stacktrace) {
      _logger.e(
        '[STT_STREAM] [+${elapsed}ms] Error resuming STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
    }
  }
}
