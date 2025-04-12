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
  StreamTranscription(this._repository) {
    print("[USECASE_DEBUG] StreamTranscription initialized");
  }

  /// Start streaming transcription
  ///
  /// Returns a stream of transcripts
  Stream<Either<Failure, Transcript>> call(StreamTranscriptionParams params) {
    print("[CRITICAL_DEBUG] StreamTranscription.call starting");
    print(
      "[USECASE_DEBUG] call method invoked with params: sessionId=${params.sessionId}, languageCode=${params.languageCode}",
    );

    try {
      final stream = _repository.streamTranscription(
        sessionId: params.sessionId,
        languageCode: params.languageCode,
      );

      print("[USECASE_DEBUG] Repository returned stream");

      // Add a listener just for debugging
      stream.listen(
        (either) {
          either.fold(
            (failure) => print(
              "[USECASE_DEBUG] Stream emitted failure: ${failure.message}",
            ),
            (transcript) => print(
              "[USECASE_DEBUG] Stream emitted transcript: ${transcript.text.substring(0, min(20, transcript.text.length))}...",
            ),
          );
        },
        onError: (e) => print("[USECASE_DEBUG] Stream error: $e"),
        onDone: () => print("[USECASE_DEBUG] Stream done"),
      );

      return stream;
    } catch (e) {
      print("[USECASE_DEBUG] Exception in call method: $e");
      rethrow;
    }
  }

  /// Stop the transcription stream
  Future<Either<Failure, void>> stop() {
    print("[USECASE_DEBUG] stop method invoked");
    return _repository.stopTranscription();
  }

  /// Pause the transcription stream
  Future<Either<Failure, void>> pause() {
    print("[USECASE_DEBUG] pause method invoked");
    return _repository.pauseTranscription();
  }

  /// Resume the transcription stream
  Future<Either<Failure, void>> resume() {
    print("[USECASE_DEBUG] resume method invoked");
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

// Helper function for string substring safety
int min(int a, int b) => a < b ? a : b;
