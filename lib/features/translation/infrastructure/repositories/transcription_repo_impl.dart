// lib/features/translation/infrastructure/repositories/transcription_repo_impl.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:hermes/config/firebase_config.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/core/services/network_checker.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/domain/repositories/transcription_repository.dart';
import 'package:hermes/features/translation/infrastructure/models/transcript_model.dart';
import 'package:hermes/features/translation/infrastructure/services/speech_to_text_service.dart';
import 'package:hermes/features/translation/infrastructure/services/audio_stream_handler.dart';

/// Implementation of [TranscriptionRepository]
@LazySingleton(as: TranscriptionRepository)
class TranscriptionRepositoryImpl implements TranscriptionRepository {
  final SpeechToTextService _sttService;
  final FirebaseFirestore _firestore;
  final NetworkChecker _networkChecker;
  final Logger _logger;
  final _uuid = const Uuid();

  StreamSubscription? _transcriptionSubscription;
  StreamController<Either<Failure, Transcript>>? _transcriptStreamController;

  /// Creates a new [TranscriptionRepositoryImpl]
  TranscriptionRepositoryImpl(
    this._sttService,
    this._firestore,
    this._networkChecker,
    this._logger,
  );

  @override
  Stream<Either<Failure, Transcript>> streamTranscription({
    required String sessionId,
    required String languageCode,
  }) {
    // Close existing stream if any
    _transcriptStreamController?.close();
    _transcriptionSubscription?.cancel();

    // Create a new stream controller
    _transcriptStreamController =
        StreamController<Either<Failure, Transcript>>.broadcast();

    _initializeTranscriptionStream(sessionId, languageCode);

    return _transcriptStreamController!.stream;
  }

  /// Initialize the transcription stream
  Future<void> _initializeTranscriptionStream(
    String sessionId,
    String languageCode,
  ) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        _transcriptStreamController?.add(const Left(NetworkFailure()));
        return;
      }

      // Start the STT service
      final sttStream = _sttService.startStreaming(
        sessionId: sessionId,
        languageCode: languageCode,
      );

      // Subscribe to STT results
      _transcriptionSubscription = sttStream.listen(
        (result) async {
          // Create transcript entity
          final transcript = Transcript(
            id: _uuid.v4(),
            sessionId: sessionId,
            text: result.transcript,
            language: languageCode,
            timestamp: DateTime.now(),
            isFinal: result.isFinal,
          );

          // Add to stream
          _transcriptStreamController?.add(Right(transcript));

          // Save final transcripts to Firestore
          if (result.isFinal && result.transcript.isNotEmpty) {
            await saveTranscript(transcript);
          }
        },
        onError: (error) {
          _logger.e('Error in STT stream', error: error);
          _transcriptStreamController?.add(
            Left(SpeechRecognitionFailure(message: error.toString())),
          );
        },
        onDone: () {
          _logger.i('STT stream closed');
        },
      );
    } catch (e, stacktrace) {
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
    try {
      await _sttService.stopStreaming();
      await _transcriptionSubscription?.cancel();
      _transcriptionSubscription = null;

      return const Right(null);
    } catch (e, stacktrace) {
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
    try {
      await _sttService.pauseStreaming();
      return const Right(null);
    } catch (e, stacktrace) {
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
    try {
      await _sttService.resumeStreaming();
      return const Right(null);
    } catch (e, stacktrace) {
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
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      final results = await _sttService.transcribeAudio(
        audioData: audioData,
        languageCode: languageCode,
      );

      if (results.isEmpty) {
        return const Left(
          SpeechRecognitionFailure(message: 'No transcription results'),
        );
      }

      // Get the best result (highest confidence)
      final bestResult = results.reduce(
        (curr, next) => curr.confidence > next.confidence ? curr : next,
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
      final savedTranscriptResult = await saveTranscript(transcript);

      return savedTranscriptResult;
    } catch (e, stacktrace) {
      _logger.e('Failed to transcribe audio', error: e, stackTrace: stacktrace);
      return Left(SpeechRecognitionFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Transcript>> saveTranscript(
    Transcript transcript,
  ) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      // Convert domain entity to model
      final transcriptModel = TranscriptModel.fromEntity(transcript);

      // Save to Firestore
      await _firestore
          .collection(FirestoreCollections.transcripts)
          .doc(transcript.id)
          .set(transcriptModel.toJson());

      return Right(transcript);
    } catch (e, stacktrace) {
      _logger.e('Failed to save transcript', error: e, stackTrace: stacktrace);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Transcript>>> getSessionTranscripts(
    String sessionId,
  ) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      final querySnapshot =
          await _firestore
              .collection(FirestoreCollections.transcripts)
              .where('session_id', isEqualTo: sessionId)
              .where('is_final', isEqualTo: true)
              .orderBy('timestamp')
              .get();

      final transcripts =
          querySnapshot.docs
              .map((doc) => TranscriptModel.fromJson(doc.data()).toEntity())
              .toList();

      return Right(transcripts);
    } catch (e, stacktrace) {
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
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      final querySnapshot =
          await _firestore
              .collection(FirestoreCollections.transcripts)
              .where('session_id', isEqualTo: sessionId)
              .where('is_final', isEqualTo: true)
              .orderBy('timestamp', descending: true)
              .limit(limit)
              .get();

      final transcripts =
          querySnapshot.docs
              .map((doc) => TranscriptModel.fromJson(doc.data()).toEntity())
              .toList();

      // Return in chronological order (oldest first)
      transcripts.sort((a, b) => a.timestamp.compareTo(b.timestamp));

      return Right(transcripts);
    } catch (e, stacktrace) {
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
    try {
      return _firestore
          .collection(FirestoreCollections.transcripts)
          .where('session_id', isEqualTo: sessionId)
          .where('is_final', isEqualTo: true)
          .orderBy('timestamp')
          .snapshots()
          .map<Either<Failure, List<Transcript>>>((snapshot) {
            try {
              final transcripts =
                  snapshot.docs
                      .map(
                        (doc) =>
                            TranscriptModel.fromJson(doc.data()).toEntity(),
                      )
                      .toList();
              return Right(transcripts);
            } catch (e, stacktrace) {
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
      _logger.e(
        'Failed to stream session transcripts',
        error: e,
        stackTrace: stacktrace,
      );
      return Stream.value(Left(ServerFailure(message: e.toString())));
    }
  }
}
