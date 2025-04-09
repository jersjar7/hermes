// lib/features/translation/domain/usecases/translate_text_chunk.dart

import 'package:equatable/equatable.dart';
import 'package:dartz/dartz.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/features/translation/domain/entities/translation.dart';
import 'package:hermes/features/translation/domain/repositories/translation_repository.dart';

/// Use case for translating text chunks
class TranslateTextChunk {
  final TranslationRepository _repository;

  /// Creates a new [TranslateTextChunk] use case
  TranslateTextChunk(this._repository);

  /// Translate a chunk of text to a single target language
  Future<Either<Failure, Translation>> call(
    TranslateTextChunkParams params,
  ) async {
    return await _repository.translateText(
      sessionId: params.sessionId,
      sourceText: params.sourceText,
      sourceLanguage: params.sourceLanguage,
      targetLanguage: params.targetLanguage,
    );
  }

  /// Translate a chunk of text to multiple target languages
  Future<Either<Failure, List<Translation>>> translateToMultipleLanguages(
    TranslateTextChunkMultiParams params,
  ) async {
    return await _repository.translateTextToMultipleLanguages(
      sessionId: params.sessionId,
      sourceText: params.sourceText,
      sourceLanguage: params.sourceLanguage,
      targetLanguages: params.targetLanguages,
    );
  }
}

/// Parameters for translating a text chunk to a single language
class TranslateTextChunkParams extends Equatable {
  /// ID of the session
  final String sessionId;

  /// Text to translate
  final String sourceText;

  /// Source language code
  final String sourceLanguage;

  /// Target language code
  final String targetLanguage;

  /// Creates new [TranslateTextChunkParams]
  const TranslateTextChunkParams({
    required this.sessionId,
    required this.sourceText,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  @override
  List<Object> get props => [
    sessionId,
    sourceText,
    sourceLanguage,
    targetLanguage,
  ];
}

/// Parameters for translating a text chunk to multiple languages
class TranslateTextChunkMultiParams extends Equatable {
  /// ID of the session
  final String sessionId;

  /// Text to translate
  final String sourceText;

  /// Source language code
  final String sourceLanguage;

  /// List of target language codes
  final List<String> targetLanguages;

  /// Creates new [TranslateTextChunkMultiParams]
  const TranslateTextChunkMultiParams({
    required this.sessionId,
    required this.sourceText,
    required this.sourceLanguage,
    required this.targetLanguages,
  });

  @override
  List<Object> get props => [
    sessionId,
    sourceText,
    sourceLanguage,
    targetLanguages,
  ];
}
