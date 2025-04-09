// lib/config/translation_module.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:injectable/injectable.dart';
import 'package:hermes/core/services/network_checker.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/domain/repositories/transcription_repository.dart';
import 'package:hermes/features/translation/domain/repositories/translation_repository.dart';
import 'package:hermes/features/translation/domain/usecases/stream_transcription.dart';
import 'package:hermes/features/translation/domain/usecases/translate_text_chunk.dart';
import 'package:hermes/features/translation/infrastructure/services/speech_to_text_service.dart';
import 'package:hermes/features/translation/infrastructure/services/translation_service.dart';

/// Module for translation-related dependency injection
@module
abstract class TranslationInjectableModule {
  /// Provides [StreamTranscription] use case
  @lazySingleton
  StreamTranscription provideStreamTranscription(
    TranscriptionRepository repository,
  ) => StreamTranscription(repository);

  /// Provides [TranslateTextChunk] use case
  @lazySingleton
  TranslateTextChunk provideTranslateTextChunk(
    TranslationRepository repository,
  ) => TranslateTextChunk(repository);

  /// Provides [SpeechToTextService]
  @lazySingleton
  SpeechToTextService provideSpeechToTextService(Logger logger) =>
      SpeechToTextService.create(logger);

  /// Provides [TranslationService]
  @lazySingleton
  TranslationService provideTranslationService(Logger logger) =>
      TranslationService.create(logger);
}
