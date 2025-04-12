// lib/features/translation/infrastructure/repositories/transcription_stream_handler.dart

import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:uuid/uuid.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/core/services/network_checker.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_exceptions.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_service.dart';

/// Handles streaming functionality for transcription
class TranscriptionStreamHandler {
  final SpeechToTextService _sttService;
  final NetworkChecker _networkChecker;
  final Logger _logger;
  final _uuid = const Uuid();

  bool _isStreamingActive = false;
  DateTime? _streamStartTime;

  StreamSubscription? _transcriptionSubscription;
  StreamController<Either<Failure, Transcript>>? _transcriptStreamController;

  // Track active stream sessions for cleanup
  final Map<String, bool> _activeSessionIds = {};

  /// Creates a new [TranscriptionStreamHandler]
  TranscriptionStreamHandler(
    this._sttService,
    this._networkChecker,
    this._logger,
  );

  /// Initialize the stream handler and related services
  Future<bool> initialize() async {
    print("[STREAM_HANDLER] Initializing STT service");
    try {
      final initialized = await _sttService.init();
      print("[STREAM_HANDLER] STT service initialization result: $initialized");
      return initialized;
    } catch (e) {
      _logger.e("[STREAM_HANDLER] Error initializing STT service", error: e);
      return false;
    }
  }

  /// Check if a stream controller is valid (not null and not closed)
  bool _isStreamControllerValid() {
    return _transcriptStreamController != null &&
        !_transcriptStreamController!.isClosed &&
        _transcriptStreamController!.hasListener;
  }

  /// Stream transcription for a session
  Stream<Either<Failure, Transcript>> streamTranscription({
    required String sessionId,
    required String languageCode,
  }) {
    print("[CRITICAL_DEBUG] StreamHandler.streamTranscription starting");
    print(
      "[STREAM_HANDLER] streamTranscription called with languageCode=$languageCode",
    );

    _streamStartTime = DateTime.now();

    // Track this session as active
    _activeSessionIds[sessionId] = true;

    // Prevent duplicate streams by cleaning up any existing stream
    _cleanupExistingStream();

    // Create a new stream controller
    print("[STREAM_HANDLER] Creating new stream controller");
    _transcriptStreamController = StreamController<
      Either<Failure, Transcript>
    >.broadcast(
      onListen: () {
        print(
          "[STREAM_HANDLER] First listener subscribed to transcript stream",
        );
      },
      onCancel: () {
        print(
          "[STREAM_HANDLER] Last listener unsubscribed from transcript stream",
        );

        // Auto cleanup when no listeners remain
        if (_transcriptStreamController != null &&
            !_transcriptStreamController!.hasListener) {
          _cleanupExistingStream();
        }
      },
    );
    print(
      "[CRITICAL_DEBUG] StreamHandler creating controller and starting _initializeTranscriptionStream",
    );
    _isStreamingActive = true;

    // Initialize the stream asynchronously
    print("[STREAM_HANDLER] Starting _initializeTranscriptionStream");
    _initializeTranscriptionStream(sessionId, languageCode);
    print(
      "[STREAM_HANDLER] Stream controller created: ${_transcriptStreamController != null}, returning stream",
    );
    return _transcriptStreamController!.stream;
  }

  /// Clean up existing stream resources
  Future<void> _cleanupExistingStream() async {
    print(
      "[STREAM_HANDLER] Cleanup reason: ${_transcriptStreamController?.hasListener ?? false ? 'still has listeners' : 'no listeners'}",
    );
    if (_isStreamingActive) {
      print("[STREAM_HANDLER] Cleaning up existing stream");

      // Cancel subscription if active
      if (_transcriptionSubscription != null) {
        try {
          await _transcriptionSubscription!.cancel();
          print("[STREAM_HANDLER] Existing subscription canceled");
        } catch (e) {
          _logger.e("[STREAM_HANDLER] Error canceling subscription", error: e);
        } finally {
          _transcriptionSubscription = null;
        }
      }

      // Close the stream controller if it's not already closed
      if (_transcriptStreamController != null) {
        try {
          if (!_transcriptStreamController!.isClosed) {
            await _transcriptStreamController!.close();
            print("[STREAM_HANDLER] Existing stream controller closed");
          }
        } catch (e) {
          _logger.e(
            "[STREAM_HANDLER] Error closing stream controller",
            error: e,
          );
        } finally {
          _transcriptStreamController = null;
        }
      }

      _isStreamingActive = false;
    }
  }

  /// Initialize the transcription stream
  Future<void> _initializeTranscriptionStream(
    String sessionId,
    String languageCode,
  ) async {
    print("[STREAM_HANDLER] _initializeTranscriptionStream started");
    print(
      "[CRITICAL_DEBUG] _initializeTranscriptionStream starting for session $sessionId",
    );

    // Check if this session is still active (hasn't been canceled/navigated away from)
    if (!_activeSessionIds.containsKey(sessionId) ||
        _activeSessionIds[sessionId] != true) {
      print(
        "[STREAM_HANDLER] Session $sessionId is no longer active, aborting stream initialization",
      );
      return;
    }

    try {
      print("[CRITICAL_DEBUG] About to check network connection");
      print("[STREAM_HANDLER] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        print("[STREAM_HANDLER] No network connection");
        _safeAddToStream(const Left(NetworkFailure()));
        return;
      }
      print("[STREAM_HANDLER] Network connection available");
      print("[CRITICAL_DEBUG] Network check passed, proceeding");

      try {
        print("[CRITICAL_DEBUG] About to ensure STT service is initialized");
        // First ensure STT service is initialized
        print("[STREAM_HANDLER] Ensuring STT service is initialized");
        final initialized = await _sttService.init();
        if (!initialized) {
          print("[STREAM_HANDLER] Failed to initialize STT service");
          _safeAddToStream(
            Left(
              SpeechRecognitionFailure(
                message: 'Failed to initialize speech recognition service',
              ),
            ),
          );
          return;
        }
        print("[STREAM_HANDLER] STT service initialized successfully");
        print("[CRITICAL_DEBUG] STT service initialized: $initialized");

        // Add a delay to ensure initialization completes
        await Future.delayed(const Duration(milliseconds: 100));

        // Check if session is still active after delay
        if (!_activeSessionIds.containsKey(sessionId) ||
            _activeSessionIds[sessionId] != true) {
          print(
            "[STREAM_HANDLER] Session $sessionId is no longer active after delay, aborting",
          );
          return;
        }

        // Start the STT service
        print("[CRITICAL_DEBUG] Attempting to start STT service");
        print(
          "[STREAM_HANDLER] Starting STT service with sessionId=$sessionId, languageCode=$languageCode",
        );
        final sttStream = _sttService.startStreaming(
          sessionId: sessionId,
          languageCode: languageCode,
        );
        print("[STREAM_HANDLER] STT service started, got stream");
        print(
          "[STREAM_HANDLER] STT service started, listening for first result...",
        );

        // Subscribe to STT results
        print("[STREAM_HANDLER] Subscribing to STT results");
        _transcriptionSubscription = sttStream.listen(
          (result) async {
            final elapsed =
                _streamStartTime != null
                    ? DateTime.now()
                        .difference(_streamStartTime!)
                        .inMilliseconds
                    : 0;

            print(
              '[STREAM_HANDLER] [+${elapsed}ms] STT result received: confidence=${result.confidence}, isFinal=${result.isFinal}',
            );
            print(
              '[STREAM_HANDLER] [+${elapsed}ms] Transcript text: "${result.transcript}"',
            );

            // Check if session still active
            if (!_activeSessionIds.containsKey(sessionId) ||
                _activeSessionIds[sessionId] != true) {
              print(
                "[STREAM_HANDLER] Session $sessionId no longer active, ignoring result",
              );
              return;
            }

            print("[STREAM_HANDLER] Received audio data chunk");

            final transcript = Transcript(
              id: _uuid.v4(),
              sessionId: sessionId,
              text: result.transcript,
              language: languageCode,
              timestamp: DateTime.now(),
              isFinal: result.isFinal,
            );

            print(
              "[STREAM_HANDLER] [+${elapsed}ms] Adding transcript to stream",
            );
            _safeAddToStream(Right(transcript));
          },
          onError: (error) {
            final elapsed =
                _streamStartTime != null
                    ? DateTime.now()
                        .difference(_streamStartTime!)
                        .inMilliseconds
                    : 0;

            print(
              "[STREAM_HANDLER] [+${elapsed}ms] Error in STT stream: $error",
            );
            _logger.e('[STREAM_HANDLER] Error in STT stream', error: error);

            final errorMessage =
                error is MicrophonePermissionException
                    ? 'Microphone permission denied. Please grant access.'
                    : 'Error in speech recognition: ${error.toString()}';

            _safeAddToStream(
              Left(SpeechRecognitionFailure(message: errorMessage)),
            );
          },
          onDone: () {
            final elapsed =
                _streamStartTime != null
                    ? DateTime.now()
                        .difference(_streamStartTime!)
                        .inMilliseconds
                    : 0;

            print("[STREAM_HANDLER] [+${elapsed}ms] STT stream closed");

            // Auto cleanup when stream is done
            if (_activeSessionIds.containsKey(sessionId)) {
              _activeSessionIds.remove(sessionId);
            }
          },
          cancelOnError: false, // Don't cancel on error to allow recovery
        );
      } catch (e) {
        final elapsed =
            _streamStartTime != null
                ? DateTime.now().difference(_streamStartTime!).inMilliseconds
                : 0;

        print(
          "[STREAM_HANDLER] [+${elapsed}ms] Exception when starting STT service: $e",
        );
        if (e is MicrophonePermissionException) {
          print(
            "[STREAM_HANDLER] [+${elapsed}ms] Microphone permission exception",
          );
          _safeAddToStream(
            Left(
              SpeechRecognitionFailure(
                message:
                    'Microphone permission required. Please grant microphone access in settings.',
              ),
            ),
          );
        } else {
          print("[STREAM_HANDLER] [+${elapsed}ms] General exception: $e");
          _safeAddToStream(
            Left(SpeechRecognitionFailure(message: e.toString())),
          );
        }
        _logger.e('Failed to start STT service', error: e);
      }
    } catch (e, stacktrace) {
      final elapsed =
          _streamStartTime != null
              ? DateTime.now().difference(_streamStartTime!).inMilliseconds
              : 0;

      print(
        "[STREAM_HANDLER] [+${elapsed}ms] Exception in _initializeTranscriptionStream: $e",
      );
      print("[STREAM_HANDLER] [+${elapsed}ms] Stack trace: $stacktrace");
      _logger.e(
        'Failed to initialize transcription stream',
        error: e,
        stackTrace: stacktrace,
      );
      _safeAddToStream(Left(SpeechRecognitionFailure(message: e.toString())));
    }
  }

  /// Safely add events to stream controller with null/closure checks
  void _safeAddToStream(Either<Failure, Transcript> event) {
    if (_isStreamControllerValid()) {
      _transcriptStreamController!.add(event);
    } else {
      print("[STREAM_HANDLER] Attempted to add to invalid stream controller");
    }
  }

  /// Stop transcription
  Future<Either<Failure, void>> stopTranscription() async {
    print("[STREAM_HANDLER] stopTranscription called");

    try {
      // Stop STT service
      print("[STREAM_HANDLER] Stopping STT service");
      await _sttService.stopStreaming();

      // Clean up stream resources
      await _cleanupExistingStream();

      // Clear all active sessions
      _activeSessionIds.clear();

      print("[STREAM_HANDLER] Transcription stopped");
      return const Right(null);
    } catch (e, stacktrace) {
      print("[STREAM_HANDLER] Exception in stopTranscription: $e");
      _logger.e(
        'Failed to stop transcription',
        error: e,
        stackTrace: stacktrace,
      );
      return Left(SpeechRecognitionFailure(message: e.toString()));
    }
  }

  /// Pause transcription
  Future<Either<Failure, void>> pauseTranscription() async {
    print("[STREAM_HANDLER] pauseTranscription called");
    try {
      print("[STREAM_HANDLER] Pausing STT service");
      await _sttService.pauseStreaming();
      print("[STREAM_HANDLER] STT service paused");
      return const Right(null);
    } catch (e, stacktrace) {
      print("[STREAM_HANDLER] Exception in pauseTranscription: $e");
      _logger.e(
        'Failed to pause transcription',
        error: e,
        stackTrace: stacktrace,
      );
      return Left(SpeechRecognitionFailure(message: e.toString()));
    }
  }

  /// Resume transcription
  Future<Either<Failure, void>> resumeTranscription() async {
    print("[STREAM_HANDLER] resumeTranscription called");
    try {
      print("[STREAM_HANDLER] Resuming STT service");
      await _sttService.resumeStreaming();
      print("[STREAM_HANDLER] STT service resumed");
      return const Right(null);
    } catch (e, stacktrace) {
      print("[STREAM_HANDLER] Exception in resumeTranscription: $e");
      _logger.e(
        'Failed to resume transcription',
        error: e,
        stackTrace: stacktrace,
      );
      return Left(SpeechRecognitionFailure(message: e.toString()));
    }
  }

  /// Cleanup a specific session
  void cleanupSession(String sessionId) {
    print("[STREAM_HANDLER] Cleaning up session $sessionId");
    if (_activeSessionIds.containsKey(sessionId)) {
      _activeSessionIds.remove(sessionId);
    }

    // If this is the current active session, clean up resources
    if (_isStreamingActive) {
      _cleanupExistingStream();
    }
  }
}
