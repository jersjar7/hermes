// lib/features/translation/domain/repositories/translation_repository.dart

import 'package:dartz/dartz.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/features/translation/domain/entities/translation.dart';

/// Repository interface for translation operations
abstract class TranslationRepository {
  /// Translate text from one language to another
  Future<Either<Failure, Translation>> translateText({
    required String sessionId,
    required String sourceText,
    required String sourceLanguage,
    required String targetLanguage,
  });

  /// Translate text to multiple languages at once
  Future<Either<Failure, List<Translation>>> translateTextToMultipleLanguages({
    required String sessionId,
    required String sourceText,
    required String sourceLanguage,
    required List<String> targetLanguages,
  });

  /// Save a translation to storage
  Future<Either<Failure, Translation>> saveTranslation(Translation translation);

  /// Get translations for a session by target language
  Future<Either<Failure, List<Translation>>> getSessionTranslations({
    required String sessionId,
    required String targetLanguage,
  });

  /// Stream translations for a session by target language
  Stream<Either<Failure, List<Translation>>> streamSessionTranslations({
    required String sessionId,
    required String targetLanguage,
  });

  /// Get available target languages
  Future<Either<Failure, List<String>>> getAvailableLanguages(
    String sourceLanguage,
  );
}
