// lib/features/translation/infrastructure/repositories/transcription_repo_impl.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:hermes/features/translation/infrastructure/repositories/transcription_stream_handler.dart';
import 'package:injectable/injectable.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/domain/repositories/transcription_repository.dart';
import 'package:hermes/features/translation/infrastructure/repositories/transcription_firestore_handler.dart';
import 'package:hermes/features/translation/infrastructure/repositories/transcription_audio_handler.dart';

/// Implementation of [TranscriptionRepository]
@LazySingleton(as: TranscriptionRepository)
class TranscriptionRepositoryImpl implements TranscriptionRepository {
  final TranscriptionStreamHandler _streamHandler;
  final TranscriptionFirestoreHandler _firestoreHandler;
  final TranscriptionAudioHandler _audioHandler;
  final Logger _logger;

  /// Creates a new [TranscriptionRepositoryImpl]
  TranscriptionRepositoryImpl(
    this._streamHandler, // Remove @Named annotation
    this._firestoreHandler,
    this._audioHandler,
    this._logger,
  ) {
    print("[REPO_DEBUG] TranscriptionRepositoryImpl constructor called");

    // Initialize services
    _initializeServices();
  }

  // Initialize services needed by the repository
  Future<void> _initializeServices() async {
    print("[REPO_DEBUG] Initializing services");
    try {
      await _streamHandler.initialize();
    } catch (e) {
      _logger.e("[REPO_DEBUG] Error pre-initializing services", error: e);
      // Don't throw - just log the error
    }
  }

  @override
  Stream<Either<Failure, Transcript>> streamTranscription({
    required String sessionId,
    required String languageCode,
  }) {
    print("[CRITICAL_DEBUG] Repository.streamTranscription called");
    print(
      "[REPO_DEBUG] streamTranscription called with languageCode=$languageCode",
    );
    print("[CRITICAL_DEBUG] About to call streamHandler.streamTranscription");
    return _streamHandler.streamTranscription(
      sessionId: sessionId,
      languageCode: languageCode,
    );
  }

  @override
  Future<Either<Failure, void>> stopTranscription() async {
    print("[REPO_DEBUG] stopTranscription called");
    return await _streamHandler.stopTranscription();
  }

  @override
  Future<Either<Failure, void>> pauseTranscription() async {
    print("[REPO_DEBUG] pauseTranscription called");
    return await _streamHandler.pauseTranscription();
  }

  @override
  Future<Either<Failure, void>> resumeTranscription() async {
    print("[REPO_DEBUG] resumeTranscription called");
    return await _streamHandler.resumeTranscription();
  }

  @override
  Future<Either<Failure, Transcript>> transcribeAudio({
    required String sessionId,
    required Uint8List audioData,
    required String languageCode,
  }) async {
    print("[REPO_DEBUG] transcribeAudio called");
    return await _audioHandler.transcribeAudio(
      sessionId: sessionId,
      audioData: audioData,
      languageCode: languageCode,
    );
  }

  @override
  Future<Either<Failure, Transcript>> saveTranscript(
    Transcript transcript,
  ) async {
    print("[REPO_DEBUG] saveTranscript called");
    return await _firestoreHandler.saveTranscript(transcript);
  }

  @override
  Future<Either<Failure, List<Transcript>>> getSessionTranscripts(
    String sessionId,
  ) async {
    print("[REPO_DEBUG] getSessionTranscripts called");
    return await _firestoreHandler.getSessionTranscripts(sessionId);
  }

  @override
  Future<Either<Failure, List<Transcript>>> getRecentTranscripts({
    required String sessionId,
    int limit = 20,
  }) async {
    print("[REPO_DEBUG] getRecentTranscripts called");
    return await _firestoreHandler.getRecentTranscripts(
      sessionId: sessionId,
      limit: limit,
    );
  }

  @override
  Stream<Either<Failure, List<Transcript>>> streamSessionTranscripts(
    String sessionId,
  ) {
    print("[REPO_DEBUG] streamSessionTranscripts called");
    return _firestoreHandler.streamSessionTranscripts(sessionId);
  }
}
