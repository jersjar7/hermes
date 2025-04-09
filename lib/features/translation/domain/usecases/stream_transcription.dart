// lib/features/translation/domain/usecases/stream_transcription.dart

import 'package:equatable/equatable.dart';
import 'package:dartz/dartz.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/domain/repositories/transcription_repository.dart';

/// Use case for streaming transcription
class StreamTranscription {
  final TranscriptionRepository _repository;

  /// Creates a new [StreamTranscription] use case
  StreamTranscription(this._repository);

  /// Start streaming transcription
  ///
  /// Returns a stream of transcripts
  Stream<Either<Failure, Transcript>> call(StreamTranscriptionParams params) {
    return _repository.streamTranscription(
      sessionId: params.sessionId,
      languageCode: params.languageCode,
    );
  }

  /// Stop the transcription stream
  Future<Either<Failure, void>> stop() {
    return _repository.stopTranscription();
  }

  /// Pause the transcription stream
  Future<Either<Failure, void>> pause() {
    return _repository.pauseTranscription();
  }

  /// Resume the transcription stream
  Future<Either<Failure, void>> resume() {
    return _repository.resumeTranscription();
  }
}

/// Parameters for streaming transcription
class StreamTranscriptionParams extends Equatable {
  /// ID of the session
  final String sessionId;

  /// Language code to transcribe
  final String languageCode;

  /// Creates new [StreamTranscriptionParams]
  const StreamTranscriptionParams({
    required this.sessionId,
    required this.languageCode,
  });

  @override
  List<Object> get props => [sessionId, languageCode];
}
