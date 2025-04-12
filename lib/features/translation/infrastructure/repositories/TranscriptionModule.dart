// lib/features/translation/infrastructure/repositories/TranscriptionModule.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:hermes/core/services/network_checker.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/infrastructure/repositories/TranscriptionAudioHandler.dart';
import 'package:hermes/features/translation/infrastructure/repositories/TranscriptionFirestoreHandler.dart';
import 'package:hermes/features/translation/infrastructure/repositories/TranscriptionStreamHandler.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_service.dart';

/// Provides dependencies for the transcription handlers
@module
abstract class TranscriptionModule {
  /// Provides [TranscriptionStreamHandler]
  @lazySingleton
  TranscriptionStreamHandler provideTranscriptionStreamHandler(
    SpeechToTextService sttService,
    NetworkChecker networkChecker,
    Logger logger,
  ) => TranscriptionStreamHandler(sttService, networkChecker, logger);

  /// Provides [TranscriptionFirestoreHandler]
  @lazySingleton
  TranscriptionFirestoreHandler provideTranscriptionFirestoreHandler(
    FirebaseFirestore firestore,
    NetworkChecker networkChecker,
    Logger logger,
  ) => TranscriptionFirestoreHandler(firestore, networkChecker, logger);

  /// Provides [TranscriptionAudioHandler]
  @lazySingleton
  TranscriptionAudioHandler provideTranscriptionAudioHandler(
    SpeechToTextService sttService,
    NetworkChecker networkChecker,
    Logger logger,
  ) => TranscriptionAudioHandler(sttService, networkChecker, logger);

  /// Provides [SpeechToTextService]
  @lazySingleton
  SpeechToTextService provideSpeechToTextService(Logger logger) {
    return SpeechToTextService.create(logger);
  }
}
