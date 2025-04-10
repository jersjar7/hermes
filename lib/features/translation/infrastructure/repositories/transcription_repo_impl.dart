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

  StreamSubscription? _transcriptionSubscription;
  StreamController<Either<Failure, Transcript>>? _transcriptStreamController;

  /// Creates a new [TranscriptionRepositoryImpl]
  TranscriptionRepositoryImpl(
    this._sttService,
    this._firestore,
    this._networkChecker,
    this._logger,
  ) {
    print("[REPO_DEBUG] TranscriptionRepositoryImpl constructor called");
  }

  @override
  Stream<Either<Failure, Transcript>> streamTranscription({
    required String sessionId,
    required String languageCode,
  }) {
    print(
      "[REPO_DEBUG] streamTranscription called with languageCode=$languageCode",
    );

    // Prevent duplicate streams by cleaning up any existing stream
    _cleanupExistingStream();

    // Create a new stream controller
    print("[REPO_DEBUG] Creating new stream controller");
    _transcriptStreamController =
        StreamController<Either<Failure, Transcript>>.broadcast();
    _isStreamingActive = true;

    // Initialize the stream asynchronously
    print("[REPO_DEBUG] Starting _initializeTranscriptionStream");
    _initializeTranscriptionStream(sessionId, languageCode);

    return _transcriptStreamController!.stream;
  }

  // Add this method to clean up existing streams
  void _cleanupExistingStream() {
    if (_isStreamingActive) {
      print("[REPO_DEBUG] Cleaning up existing stream");

      // Cancel subscription first
      if (_transcriptionSubscription != null) {
        _transcriptionSubscription?.cancel();
        _transcriptionSubscription = null;
        print("[REPO_DEBUG] Existing subscription canceled");
      }

      // Then close controller if it exists and isn't already closed
      if (_transcriptStreamController != null &&
          !_transcriptStreamController!.isClosed) {
        _transcriptStreamController?.close();
        print("[REPO_DEBUG] Existing stream controller closed");
      }

      _isStreamingActive = false;
    }
  }

  /// Initialize the transcription stream
  Future<void> _initializeTranscriptionStream(
    String sessionId,
    String languageCode,
  ) async {
    print("[REPO_DEBUG] _initializeTranscriptionStream started");
    try {
      print("[REPO_DEBUG] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        print("[REPO_DEBUG] No network connection");
        _transcriptStreamController?.add(const Left(NetworkFailure()));
        return;
      }
      print("[REPO_DEBUG] Network connection available");

      try {
        // Start the STT service
        print("[REPO_DEBUG] Starting STT service");
        final sttStream = _sttService.startStreaming(
          sessionId: sessionId,
          languageCode: languageCode,
        );
        print("[REPO_DEBUG] STT service started, got stream");

        // Subscribe to STT results
        print("[REPO_DEBUG] Subscribing to STT results");
        _transcriptionSubscription = sttStream.listen(
          (result) async {
            print(
              "[REPO_DEBUG] Received result: transcript='${result.transcript}', isFinal=${result.isFinal}",
            );
            final transcript = Transcript(
              id: _uuid.v4(),
              sessionId: sessionId,
              text: result.transcript,
              language: languageCode,
              timestamp: DateTime.now(),
              isFinal: result.isFinal,
            );

            print("[REPO_DEBUG] Adding transcript to stream");
            _transcriptStreamController?.add(Right(transcript));

            if (result.isFinal && result.transcript.isNotEmpty) {
              print("[REPO_DEBUG] Final transcript, saving to Firestore");
              await saveTranscript(transcript);
            }
          },
          onError: (error) {
            print("[REPO_DEBUG] Error in STT stream: $error");
            _logger.e('Error in STT stream', error: error);
            _transcriptStreamController?.add(
              Left(SpeechRecognitionFailure(message: error.toString())),
            );
          },
          onDone: () {
            print("[REPO_DEBUG] STT stream closed");
            _logger.i('STT stream closed');
          },
        );
      } catch (e) {
        print("[REPO_DEBUG] Exception when starting STT service: $e");
        if (e is MicrophonePermissionException) {
          print("[REPO_DEBUG] Microphone permission exception");
          _transcriptStreamController?.add(
            Left(
              SpeechRecognitionFailure(
                message:
                    'Microphone permission required. Please grant microphone access in settings.',
              ),
            ),
          );
        } else {
          print("[REPO_DEBUG] General exception: $e");
          _transcriptStreamController?.add(
            Left(SpeechRecognitionFailure(message: e.toString())),
          );
        }
        _logger.e('Failed to start STT service', error: e);
      }
    } catch (e, stacktrace) {
      print("[REPO_DEBUG] Exception in _initializeTranscriptionStream: $e");
      print("[REPO_DEBUG] Stack trace: $stacktrace");
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

  // Also enhance stopTranscription to use the cleanup method
  @override
  Future<Either<Failure, void>> stopTranscription() async {
    print("[REPO_DEBUG] stopTranscription called");

    try {
      // Stop STT service
      print("[REPO_DEBUG] Stopping STT service");
      await _sttService.stopStreaming();

      // Clean up stream resources
      _cleanupExistingStream();

      print("[REPO_DEBUG] Transcription stopped");
      return const Right(null);
    } catch (e, stacktrace) {
      print("[REPO_DEBUG] Exception in stopTranscription: $e");
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
    print("[REPO_DEBUG] pauseTranscription called");
    try {
      print("[REPO_DEBUG] Pausing STT service");
      await _sttService.pauseStreaming();
      print("[REPO_DEBUG] STT service paused");
      return const Right(null);
    } catch (e, stacktrace) {
      print("[REPO_DEBUG] Exception in pauseTranscription: $e");
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
    print("[REPO_DEBUG] resumeTranscription called");
    try {
      print("[REPO_DEBUG] Resuming STT service");
      await _sttService.resumeStreaming();
      print("[REPO_DEBUG] STT service resumed");
      return const Right(null);
    } catch (e, stacktrace) {
      print("[REPO_DEBUG] Exception in resumeTranscription: $e");
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
    print("[REPO_DEBUG] transcribeAudio called");
    try {
      print("[REPO_DEBUG] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        print("[REPO_DEBUG] No network connection");
        return const Left(NetworkFailure());
      }

      print("[REPO_DEBUG] Calling STT service transcribeAudio");
      final results = await _sttService.transcribeAudio(
        audioData: audioData,
        languageCode: languageCode,
      );

      if (results.isEmpty) {
        print("[REPO_DEBUG] No transcription results");
        return const Left(
          SpeechRecognitionFailure(message: 'No transcription results'),
        );
      }

      // Get the best result (highest confidence)
      final bestResult = results.reduce(
        (curr, next) => curr.confidence > next.confidence ? curr : next,
      );
      print(
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
      print("[REPO_DEBUG] Saving transcript to Firestore");
      final savedTranscriptResult = await saveTranscript(transcript);

      return savedTranscriptResult;
    } catch (e, stacktrace) {
      print("[REPO_DEBUG] Exception in transcribeAudio: $e");
      _logger.e('Failed to transcribe audio', error: e, stackTrace: stacktrace);
      return Left(SpeechRecognitionFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Transcript>> saveTranscript(
    Transcript transcript,
  ) async {
    print("[REPO_DEBUG] saveTranscript called");
    try {
      print("[REPO_DEBUG] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        print("[REPO_DEBUG] No network connection");
        return const Left(NetworkFailure());
      }

      // Convert domain entity to model
      print("[REPO_DEBUG] Converting domain entity to model");
      final transcriptModel = TranscriptModel.fromEntity(transcript);

      // Save to Firestore
      print(
        "[REPO_DEBUG] Saving to Firestore collection: ${FirestoreCollections.transcripts}",
      );
      await _firestore
          .collection(FirestoreCollections.transcripts)
          .doc(transcript.id)
          .set(transcriptModel.toJson());
      print("[REPO_DEBUG] Saved to Firestore");

      return Right(transcript);
    } catch (e, stacktrace) {
      print("[REPO_DEBUG] Exception in saveTranscript: $e");
      _logger.e('Failed to save transcript', error: e, stackTrace: stacktrace);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Transcript>>> getSessionTranscripts(
    String sessionId,
  ) async {
    print("[REPO_DEBUG] getSessionTranscripts called for sessionId=$sessionId");
    try {
      print("[REPO_DEBUG] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        print("[REPO_DEBUG] No network connection");
        return const Left(NetworkFailure());
      }

      print("[REPO_DEBUG] Querying Firestore");
      final querySnapshot =
          await _firestore
              .collection(FirestoreCollections.transcripts)
              .where('session_id', isEqualTo: sessionId)
              .where('is_final', isEqualTo: true)
              .orderBy('timestamp')
              .get();
      print(
        "[REPO_DEBUG] Got ${querySnapshot.docs.length} documents from Firestore",
      );

      final transcripts =
          querySnapshot.docs
              .map((doc) => TranscriptModel.fromJson(doc.data()).toEntity())
              .toList();

      return Right(transcripts);
    } catch (e, stacktrace) {
      print("[REPO_DEBUG] Exception in getSessionTranscripts: $e");
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
    print(
      "[REPO_DEBUG] getRecentTranscripts called for sessionId=$sessionId, limit=$limit",
    );
    try {
      print("[REPO_DEBUG] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        print("[REPO_DEBUG] No network connection");
        return const Left(NetworkFailure());
      }

      print("[REPO_DEBUG] Querying Firestore");
      final querySnapshot =
          await _firestore
              .collection(FirestoreCollections.transcripts)
              .where('session_id', isEqualTo: sessionId)
              .where('is_final', isEqualTo: true)
              .orderBy('timestamp', descending: true)
              .limit(limit)
              .get();
      print(
        "[REPO_DEBUG] Got ${querySnapshot.docs.length} documents from Firestore",
      );

      final transcripts =
          querySnapshot.docs
              .map((doc) => TranscriptModel.fromJson(doc.data()).toEntity())
              .toList();

      // Return in chronological order (oldest first)
      transcripts.sort((a, b) => a.timestamp.compareTo(b.timestamp));
      print("[REPO_DEBUG] Sorted ${transcripts.length} transcripts");

      return Right(transcripts);
    } catch (e, stacktrace) {
      print("[REPO_DEBUG] Exception in getRecentTranscripts: $e");
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
    print(
      "[REPO_DEBUG] streamSessionTranscripts called for sessionId=$sessionId",
    );
    try {
      print("[REPO_DEBUG] Setting up Firestore stream");
      return _firestore
          .collection(FirestoreCollections.transcripts)
          .where('session_id', isEqualTo: sessionId)
          .where('is_final', isEqualTo: true)
          .orderBy('timestamp')
          .snapshots()
          .map<Either<Failure, List<Transcript>>>((snapshot) {
            print(
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
              print("[REPO_DEBUG] Mapped ${transcripts.length} transcripts");
              return Right(transcripts);
            } catch (e, stacktrace) {
              print("[REPO_DEBUG] Error parsing transcripts: $e");
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
                print("[REPO_DEBUG] Error in stream: $error");
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
      print("[REPO_DEBUG] Exception in streamSessionTranscripts: $e");
      _logger.e(
        'Failed to stream session transcripts',
        error: e,
        stackTrace: stacktrace,
      );
      return Stream.value(Left(ServerFailure(message: e.toString())));
    }
  }
}
