// lib/features/translation/infrastructure/repositories/transcription_repo_impl.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_exceptions.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_service.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:hermes/config/firebase_config.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/core/services/network_checker.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/domain/repositories/transcription_repository.dart';
import 'package:hermes/features/translation/infrastructure/models/transcript_model.dart';

/// Implementation of [TranscriptionRepository]
@LazySingleton(as: TranscriptionRepository)
class TranscriptionRepositoryImpl implements TranscriptionRepository {
  final SpeechToTextService _sttService;
  final FirebaseFirestore _firestore;
  final NetworkChecker _networkChecker;
  final Logger _logger;
  final _uuid = const Uuid();
  bool _isStreamingActive = false;
  DateTime? _streamStartTime;

  StreamSubscription? _transcriptionSubscription;
  StreamController<Either<Failure, Transcript>>? _transcriptStreamController;

  /// Creates a new [TranscriptionRepositoryImpl]
  TranscriptionRepositoryImpl(
    this._sttService,
    this._firestore,
    this._networkChecker,
    this._logger,
  ) {
    _logger.d("[REPO_DEBUG] TranscriptionRepositoryImpl constructor called");

    // Initialize STT service early
    _initializeSTTService();
  }

  // Initialize the STT service at creation time
  Future<void> _initializeSTTService() async {
    _logger.d("[REPO_DEBUG] Pre-initializing STT service");
    try {
      final initialized = await _sttService.init();
      _logger.d(
        "[REPO_DEBUG] STT service pre-initialization result: $initialized",
      );
    } catch (e) {
      _logger.e("[REPO_DEBUG] Error pre-initializing STT service", error: e);
      // Don't throw - just log the error
    }
  }

  @override
  Stream<Either<Failure, Transcript>> streamTranscription({
    required String sessionId,
    required String languageCode,
  }) {
    _logger.d(
      "[REPO_DEBUG] streamTranscription called with languageCode=$languageCode",
    );

    _streamStartTime = DateTime.now();

    // Prevent duplicate streams by cleaning up any existing stream
    _cleanupExistingStream();

    // Create a new stream controller
    _logger.d("[REPO_DEBUG] Creating new stream controller");
    _transcriptStreamController =
        StreamController<Either<Failure, Transcript>>.broadcast(
          onListen: () {
            _logger.d(
              "[REPO_DEBUG] First listener subscribed to transcript stream",
            );
          },
          onCancel: () {
            _logger.d(
              "[REPO_DEBUG] Last listener unsubscribed from transcript stream",
            );
          },
        );
    _isStreamingActive = true;

    // Initialize the stream asynchronously
    _logger.d("[REPO_DEBUG] Starting _initializeTranscriptionStream");
    _initializeTranscriptionStream(sessionId, languageCode);

    return _transcriptStreamController!.stream;
  }

  // Add this method to clean up existing streams
  Future<void> _cleanupExistingStream() async {
    if (_isStreamingActive) {
      _logger.d("[REPO_DEBUG] Cleaning up existing stream");

      // Cancel subscription if active
      if (_transcriptionSubscription != null) {
        await _transcriptionSubscription!.cancel();
        _transcriptionSubscription = null;
        _logger.d("[REPO_DEBUG] Existing subscription canceled");
      }

      // Close the stream controller if it's not already closed
      if (_transcriptStreamController != null &&
          !_transcriptStreamController!.isClosed) {
        await _transcriptStreamController!.close();
        _logger.d("[REPO_DEBUG] Existing stream controller closed");
      }

      _transcriptStreamController = null;
      _isStreamingActive = false;
    }
  }

  /// Initialize the transcription stream
  Future<void> _initializeTranscriptionStream(
    String sessionId,
    String languageCode,
  ) async {
    _logger.d("[REPO_DEBUG] _initializeTranscriptionStream started");
    try {
      _logger.d("[REPO_DEBUG] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        _logger.d("[REPO_DEBUG] No network connection");
        _transcriptStreamController?.add(const Left(NetworkFailure()));
        return;
      }
      _logger.d("[REPO_DEBUG] Network connection available");

      try {
        // First ensure STT service is initialized
        _logger.d("[REPO_DEBUG] Ensuring STT service is initialized");
        final initialized = await _sttService.init();
        if (!initialized) {
          _logger.e("[REPO_DEBUG] Failed to initialize STT service");
          _transcriptStreamController?.add(
            Left(
              SpeechRecognitionFailure(
                message: 'Failed to initialize speech recognition service',
              ),
            ),
          );
          return;
        }
        _logger.d("[REPO_DEBUG] STT service initialized successfully");

        // Add a delay to ensure initialization completes
        await Future.delayed(const Duration(milliseconds: 100));

        // Start the STT service
        _logger.d(
          "[REPO_DEBUG] Starting STT service with sessionId=$sessionId, languageCode=$languageCode",
        );
        final sttStream = _sttService.startStreaming(
          sessionId: sessionId,
          languageCode: languageCode,
        );
        _logger.d("[REPO_DEBUG] STT service started, got stream");

        // Subscribe to STT results
        _logger.d("[REPO_DEBUG] Subscribing to STT results");
        _transcriptionSubscription = sttStream.listen(
          (result) async {
            final elapsed =
                _streamStartTime != null
                    ? DateTime.now()
                        .difference(_streamStartTime!)
                        .inMilliseconds
                    : 0;

            _logger.d(
              '[REPO_DEBUG] [+${elapsed}ms] STT result received: confidence=${result.confidence}, isFinal=${result.isFinal}',
            );
            _logger.d(
              '[REPO_DEBUG] [+${elapsed}ms] Transcript text: "${result.transcript}"',
            );

            final transcript = Transcript(
              id: _uuid.v4(),
              sessionId: sessionId,
              text: result.transcript,
              language: languageCode,
              timestamp: DateTime.now(),
              isFinal: result.isFinal,
            );

            _logger.d(
              "[REPO_DEBUG] [+${elapsed}ms] Adding transcript to stream",
            );
            _transcriptStreamController?.add(Right(transcript));

            if (result.isFinal && result.transcript.isNotEmpty) {
              _logger.d(
                "[REPO_DEBUG] [+${elapsed}ms] Final transcript, saving to Firestore",
              );
              await saveTranscript(transcript);
            }
          },
          onError: (error) {
            final elapsed =
                _streamStartTime != null
                    ? DateTime.now()
                        .difference(_streamStartTime!)
                        .inMilliseconds
                    : 0;

            _logger.d(
              "[REPO_DEBUG] [+${elapsed}ms] Error in STT stream: $error",
            );
            _logger.e('[REPO_DEBUG] Error in STT stream', error: error);

            final errorMessage =
                error is MicrophonePermissionException
                    ? 'Microphone permission denied. Please grant access.'
                    : 'Error in speech recognition: ${error.toString()}';

            _transcriptStreamController?.add(
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

            _logger.d("[REPO_DEBUG] [+${elapsed}ms] STT stream closed");
            _logger.i('STT stream closed');
          },
        );
      } catch (e) {
        final elapsed =
            _streamStartTime != null
                ? DateTime.now().difference(_streamStartTime!).inMilliseconds
                : 0;

        _logger.d(
          "[REPO_DEBUG] [+${elapsed}ms] Exception when starting STT service: $e",
        );
        if (e is MicrophonePermissionException) {
          _logger.d(
            "[REPO_DEBUG] [+${elapsed}ms] Microphone permission exception",
          );
          _transcriptStreamController?.add(
            Left(
              SpeechRecognitionFailure(
                message:
                    'Microphone permission required. Please grant microphone access in settings.',
              ),
            ),
          );
        } else {
          _logger.d("[REPO_DEBUG] [+${elapsed}ms] General exception: $e");
          _transcriptStreamController?.add(
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

      _logger.d(
        "[REPO_DEBUG] [+${elapsed}ms] Exception in _initializeTranscriptionStream: $e",
      );
      _logger.d("[REPO_DEBUG] [+${elapsed}ms] Stack trace: $stacktrace");
      _logger.e(
        'Failed to initialize transcription stream',
        error: e,
        stackTrace: stacktrace,
      );
      _transcriptStreamController?.add(
        Left(SpeechRecognitionFailure(message: e.toString())),
      );
    }
  }

  @override
  Future<Either<Failure, void>> stopTranscription() async {
    _logger.d("[REPO_DEBUG] stopTranscription called");

    try {
      // Stop STT service
      _logger.d("[REPO_DEBUG] Stopping STT service");
      await _sttService.stopStreaming();

      // Clean up stream resources
      await _cleanupExistingStream();

      _logger.d("[REPO_DEBUG] Transcription stopped");
      return const Right(null);
    } catch (e, stacktrace) {
      _logger.d("[REPO_DEBUG] Exception in stopTranscription: $e");
      _logger.e(
        'Failed to stop transcription',
        error: e,
        stackTrace: stacktrace,
      );
      return Left(SpeechRecognitionFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> pauseTranscription() async {
    _logger.d("[REPO_DEBUG] pauseTranscription called");
    try {
      _logger.d("[REPO_DEBUG] Pausing STT service");
      await _sttService.pauseStreaming();
      _logger.d("[REPO_DEBUG] STT service paused");
      return const Right(null);
    } catch (e, stacktrace) {
      _logger.d("[REPO_DEBUG] Exception in pauseTranscription: $e");
      _logger.e(
        'Failed to pause transcription',
        error: e,
        stackTrace: stacktrace,
      );
      return Left(SpeechRecognitionFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> resumeTranscription() async {
    _logger.d("[REPO_DEBUG] resumeTranscription called");
    try {
      _logger.d("[REPO_DEBUG] Resuming STT service");
      await _sttService.resumeStreaming();
      _logger.d("[REPO_DEBUG] STT service resumed");
      return const Right(null);
    } catch (e, stacktrace) {
      _logger.d("[REPO_DEBUG] Exception in resumeTranscription: $e");
      _logger.e(
        'Failed to resume transcription',
        error: e,
        stackTrace: stacktrace,
      );
      return Left(SpeechRecognitionFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Transcript>> transcribeAudio({
    required String sessionId,
    required Uint8List audioData,
    required String languageCode,
  }) async {
    _logger.d("[REPO_DEBUG] transcribeAudio called");
    try {
      _logger.d("[REPO_DEBUG] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        _logger.d("[REPO_DEBUG] No network connection");
        return const Left(NetworkFailure());
      }

      _logger.d("[REPO_DEBUG] Calling STT service transcribeAudio");
      final results = await _sttService.transcribeAudio(
        audioData: audioData,
        languageCode: languageCode,
      );

      if (results.isEmpty) {
        _logger.d("[REPO_DEBUG] No transcription results");
        return const Left(
          SpeechRecognitionFailure(message: 'No transcription results'),
        );
      }

      // Get the best result (highest confidence)
      final bestResult = results.reduce(
        (curr, next) => curr.confidence > next.confidence ? curr : next,
      );
      _logger.d(
        "[REPO_DEBUG] Best result: transcript='${bestResult.transcript}', confidence=${bestResult.confidence}",
      );

      // Create transcript entity
      final transcript = Transcript(
        id: _uuid.v4(),
        sessionId: sessionId,
        text: bestResult.transcript,
        language: languageCode,
        timestamp: DateTime.now(),
        isFinal: true,
      );

      // Save to Firestore
      _logger.d("[REPO_DEBUG] Saving transcript to Firestore");
      final savedTranscriptResult = await saveTranscript(transcript);

      return savedTranscriptResult;
    } catch (e, stacktrace) {
      _logger.d("[REPO_DEBUG] Exception in transcribeAudio: $e");
      _logger.e('Failed to transcribe audio', error: e, stackTrace: stacktrace);
      return Left(SpeechRecognitionFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Transcript>> saveTranscript(
    Transcript transcript,
  ) async {
    _logger.d("[REPO_DEBUG] saveTranscript called");
    try {
      _logger.d("[REPO_DEBUG] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        _logger.d("[REPO_DEBUG] No network connection");
        return const Left(NetworkFailure());
      }

      // Convert domain entity to model
      _logger.d("[REPO_DEBUG] Converting domain entity to model");
      final transcriptModel = TranscriptModel.fromEntity(transcript);

      // Save to Firestore
      _logger.d(
        "[REPO_DEBUG] Saving to Firestore collection: ${FirestoreCollections.transcripts}",
      );
      await _firestore
          .collection(FirestoreCollections.transcripts)
          .doc(transcript.id)
          .set(transcriptModel.toJson());
      _logger.d("[REPO_DEBUG] Saved to Firestore");

      return Right(transcript);
    } catch (e, stacktrace) {
      _logger.d("[REPO_DEBUG] Exception in saveTranscript: $e");
      _logger.e('Failed to save transcript', error: e, stackTrace: stacktrace);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Transcript>>> getSessionTranscripts(
    String sessionId,
  ) async {
    _logger.d(
      "[REPO_DEBUG] getSessionTranscripts called for sessionId=$sessionId",
    );
    try {
      _logger.d("[REPO_DEBUG] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        _logger.d("[REPO_DEBUG] No network connection");
        return const Left(NetworkFailure());
      }

      _logger.d("[REPO_DEBUG] Querying Firestore");
      final querySnapshot =
          await _firestore
              .collection(FirestoreCollections.transcripts)
              .where('session_id', isEqualTo: sessionId)
              .where('is_final', isEqualTo: true)
              .orderBy('timestamp')
              .get();
      _logger.d(
        "[REPO_DEBUG] Got ${querySnapshot.docs.length} documents from Firestore",
      );

      final transcripts =
          querySnapshot.docs
              .map((doc) => TranscriptModel.fromJson(doc.data()).toEntity())
              .toList();

      return Right(transcripts);
    } catch (e, stacktrace) {
      _logger.d("[REPO_DEBUG] Exception in getSessionTranscripts: $e");
      _logger.e(
        'Failed to get session transcripts',
        error: e,
        stackTrace: stacktrace,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Transcript>>> getRecentTranscripts({
    required String sessionId,
    int limit = 20,
  }) async {
    _logger.d(
      "[REPO_DEBUG] getRecentTranscripts called for sessionId=$sessionId, limit=$limit",
    );
    try {
      _logger.d("[REPO_DEBUG] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        _logger.d("[REPO_DEBUG] No network connection");
        return const Left(NetworkFailure());
      }

      _logger.d("[REPO_DEBUG] Querying Firestore");
      final querySnapshot =
          await _firestore
              .collection(FirestoreCollections.transcripts)
              .where('session_id', isEqualTo: sessionId)
              .where('is_final', isEqualTo: true)
              .orderBy('timestamp', descending: true)
              .limit(limit)
              .get();
      _logger.d(
        "[REPO_DEBUG] Got ${querySnapshot.docs.length} documents from Firestore",
      );

      final transcripts =
          querySnapshot.docs
              .map((doc) => TranscriptModel.fromJson(doc.data()).toEntity())
              .toList();

      // Return in chronological order (oldest first)
      transcripts.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      _logger.d("[REPO_DEBUG] Sorted ${transcripts.length} transcripts");

      return Right(transcripts);
    } catch (e, stacktrace) {
      _logger.d("[REPO_DEBUG] Exception in getRecentTranscripts: $e");
      _logger.e(
        'Failed to get recent transcripts',
        error: e,
        stackTrace: stacktrace,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<Either<Failure, List<Transcript>>> streamSessionTranscripts(
    String sessionId,
  ) {
    _logger.d(
      "[REPO_DEBUG] streamSessionTranscripts called for sessionId=$sessionId",
    );
    try {
      _logger.d("[REPO_DEBUG] Setting up Firestore stream");
      return _firestore
          .collection(FirestoreCollections.transcripts)
          .where('session_id', isEqualTo: sessionId)
          .where('is_final', isEqualTo: true)
          .orderBy('timestamp')
          .snapshots()
          .map<Either<Failure, List<Transcript>>>((snapshot) {
            _logger.d(
              "[REPO_DEBUG] Received snapshot with ${snapshot.docs.length} documents",
            );
            try {
              final transcripts =
                  snapshot.docs
                      .map(
                        (doc) =>
                            TranscriptModel.fromJson(doc.data()).toEntity(),
                      )
                      .toList();
              _logger.d(
                "[REPO_DEBUG] Mapped ${transcripts.length} transcripts",
              );
              return Right(transcripts);
            } catch (e, stacktrace) {
              _logger.d("[REPO_DEBUG] Error parsing transcripts: $e");
              _logger.e(
                'Error parsing transcripts',
                error: e,
                stackTrace: stacktrace,
              );
              return Left(ServerFailure(message: e.toString()));
            }
          })
          .transform(
            StreamTransformer.fromHandlers(
              handleError: (error, stacktrace, sink) {
                _logger.d("[REPO_DEBUG] Error in stream: $error");
                _logger.e(
                  'Error streaming transcripts',
                  error: error,
                  stackTrace: stacktrace,
                );
                sink.add(Left(ServerFailure(message: error.toString())));
              },
            ),
          );
    } catch (e, stacktrace) {
      _logger.d("[REPO_DEBUG] Exception in streamSessionTranscripts: $e");
      _logger.e(
        'Failed to stream session transcripts',
        error: e,
        stackTrace: stacktrace,
      );
      return Stream.value(Left(ServerFailure(message: e.toString())));
    }
  }
}
