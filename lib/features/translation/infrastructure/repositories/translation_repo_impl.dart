// lib/features/translation/infrastructure/repositories/translation_repo_impl.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:hermes/config/firebase_config.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/core/services/network_checker.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/domain/entities/translation.dart';
import 'package:hermes/features/translation/domain/repositories/translation_repository.dart';
import 'package:hermes/features/translation/infrastructure/models/translation_model.dart';
import 'package:hermes/features/translation/infrastructure/services/translation_service.dart';

/// Implementation of [TranslationRepository]
@LazySingleton(as: TranslationRepository)
class TranslationRepositoryImpl implements TranslationRepository {
  final TranslationService _translationService;
  final FirebaseFirestore _firestore;
  final NetworkChecker _networkChecker;
  final Logger _logger;
  final _uuid = const Uuid();

  /// Creates a new [TranslationRepositoryImpl]
  TranslationRepositoryImpl(
    this._translationService,
    this._firestore,
    this._networkChecker,
    this._logger,
  );

  @override
  Future<Either<Failure, Translation>> translateText({
    required String sessionId,
    required String sourceText,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      // Call translation service
      final result = await _translationService.translateText(
        text: sourceText,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
      );

      // Create translation entity
      final translation = Translation(
        id: _uuid.v4(),
        sessionId: sessionId,
        sourceLanguage: sourceLanguage,
        targetLanguage: targetLanguage,
        sourceText: sourceText,
        targetText: result.translatedText,
        timestamp: DateTime.now(),
      );

      // Save translation to Firestore
      final savedTranslation = await saveTranslation(translation);

      return savedTranslation;
    } catch (e, stacktrace) {
      _logger.e('Failed to translate text', error: e, stackTrace: stacktrace);
      return Left(TranslationFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Translation>>> translateTextToMultipleLanguages({
    required String sessionId,
    required String sourceText,
    required String sourceLanguage,
    required List<String> targetLanguages,
  }) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      // Call translation service
      final translationResults = await _translationService
          .translateTextToMultipleLanguages(
            text: sourceText,
            sourceLanguage: sourceLanguage,
            targetLanguages: targetLanguages,
          );

      // Create translation entities
      final translations = <Translation>[];

      for (final result in translationResults) {
        final translation = Translation(
          id: _uuid.v4(),
          sessionId: sessionId,
          sourceLanguage: sourceLanguage,
          targetLanguage: result.targetLanguage,
          sourceText: sourceText,
          targetText: result.translatedText,
          timestamp: DateTime.now(),
        );

        // Save translation to Firestore
        final savedResult = await saveTranslation(translation);

        savedResult.fold(
          (failure) => _logger.w(
            'Failed to save translation for ${result.targetLanguage}: ${failure.message}',
          ),
          (savedTranslation) => translations.add(savedTranslation),
        );
      }

      if (translations.isEmpty) {
        return const Left(
          TranslationFailure(
            message: 'Failed to translate to any target language',
          ),
        );
      }

      return Right(translations);
    } catch (e, stacktrace) {
      _logger.e(
        'Failed to translate text to multiple languages',
        error: e,
        stackTrace: stacktrace,
      );
      return Left(TranslationFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Translation>> saveTranslation(
    Translation translation,
  ) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      // Convert domain entity to model
      final translationModel = TranslationModel.fromEntity(translation);

      // Save to Firestore
      await _firestore
          .collection(FirestoreCollections.translations)
          .doc(translation.id)
          .set(translationModel.toJson());

      return Right(translation);
    } catch (e, stacktrace) {
      _logger.e('Failed to save translation', error: e, stackTrace: stacktrace);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Translation>>> getSessionTranslations({
    required String sessionId,
    required String targetLanguage,
  }) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      final querySnapshot =
          await _firestore
              .collection(FirestoreCollections.translations)
              .where('session_id', isEqualTo: sessionId)
              .where('target_language', isEqualTo: targetLanguage)
              .orderBy('timestamp')
              .get();

      final translations =
          querySnapshot.docs
              .map((doc) => TranslationModel.fromJson(doc.data()).toEntity())
              .toList();

      return Right(translations);
    } catch (e, stacktrace) {
      _logger.e(
        'Failed to get session translations',
        error: e,
        stackTrace: stacktrace,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<Either<Failure, List<Translation>>> streamSessionTranslations({
    required String sessionId,
    required String targetLanguage,
  }) {
    try {
      return _firestore
          .collection(FirestoreCollections.translations)
          .where('session_id', isEqualTo: sessionId)
          .where('target_language', isEqualTo: targetLanguage)
          .orderBy('timestamp')
          .snapshots()
          .map<Either<Failure, List<Translation>>>((snapshot) {
            try {
              final translations =
                  snapshot.docs
                      .map(
                        (doc) =>
                            TranslationModel.fromJson(doc.data()).toEntity(),
                      )
                      .toList();
              return Right(translations);
            } catch (e, stacktrace) {
              _logger.e(
                'Error parsing translations',
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
                  'Error streaming translations',
                  error: error,
                  stackTrace: stacktrace,
                );
                sink.add(Left(ServerFailure(message: error.toString())));
              },
            ),
          );
    } catch (e, stacktrace) {
      _logger.e(
        'Failed to stream session translations',
        error: e,
        stackTrace: stacktrace,
      );
      return Stream.value(Left(ServerFailure(message: e.toString())));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getAvailableLanguages(
    String sourceLanguage,
  ) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      // Get supported languages from translation service
      final supportedLanguages = await _translationService
          .getSupportedLanguages(displayLanguage: 'en');

      // Extract language codes
      final languageCodes =
          supportedLanguages
              .map((lang) => lang.languageCode)
              .where(
                (code) => code != sourceLanguage,
              ) // Exclude source language
              .toList();

      return Right(languageCodes);
    } catch (e, stacktrace) {
      _logger.e(
        'Failed to get available languages',
        error: e,
        stackTrace: stacktrace,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }
}
