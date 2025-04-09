// lib/features/translation/domain/repositories/transcription_repository.dart

import 'dart:typed_data';
import 'package:dartz/dartz.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';

/// Repository interface for transcription operations
abstract class TranscriptionRepository {
  /// Start streaming transcription for a session
  ///
  /// Returns a stream of transcripts. The boolean indicates if the transcription is final.
  Stream<Either<Failure, Transcript>> streamTranscription({
    required String sessionId,
    required String languageCode,
  });

  /// Stop the transcription stream
  Future<Either<Failure, void>> stopTranscription();

  /// Pause the transcription stream
  Future<Either<Failure, void>> pauseTranscription();

  /// Resume the transcription stream
  Future<Either<Failure, void>> resumeTranscription();

  /// Send audio data for transcription
  ///
  /// This is used when not using the microphone directly
  Future<Either<Failure, Transcript>> transcribeAudio({
    required String sessionId,
    required Uint8List audioData,
    required String languageCode,
  });

  /// Save a transcript to storage
  Future<Either<Failure, Transcript>> saveTranscript(Transcript transcript);

  /// Get transcripts for a session
  Future<Either<Failure, List<Transcript>>> getSessionTranscripts(
    String sessionId,
  );

  /// Get recent transcripts for a session
  Future<Either<Failure, List<Transcript>>> getRecentTranscripts({
    required String sessionId,
    int limit = 20,
  });

  /// Stream transcripts for a session
  Stream<Either<Failure, List<Transcript>>> streamSessionTranscripts(
    String sessionId,
  );
}
