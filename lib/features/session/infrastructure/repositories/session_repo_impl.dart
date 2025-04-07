// lib/features/session/infrastructure/repositories/session_repo_impl.dart

import 'dart:async';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:hermes/config/firebase_config.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/core/services/network_checker.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/session/domain/repositories/session_repository.dart';
import 'package:hermes/features/session/infrastructure/datasources/session_remote_ds.dart';
import 'package:hermes/features/session/infrastructure/models/session_model.dart';

/// Implementation of [SessionRepository]
@LazySingleton(as: SessionRepository)
class SessionRepositoryImpl implements SessionRepository {
  final SessionRemoteDataSource _remoteDataSource;
  final NetworkChecker _networkChecker;
  final Logger _logger;

  /// Creates a new [SessionRepositoryImpl]
  SessionRepositoryImpl(
    this._remoteDataSource,
    this._networkChecker,
    this._logger,
  );

  @override
  Future<Either<Failure, Session>> createSession({
    required String name,
    required String speakerId,
    required String sourceLanguage,
  }) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      // Generate unique session code
      final codeResult = await generateSessionCode();

      if (codeResult.isLeft()) {
        return Left(
          codeResult.fold(
            (l) => l,
            (r) =>
                const ServerFailure(message: 'Failed to generate session code'),
          ),
        );
      }

      final code = codeResult.getOrElse(() => '');

      final session = await _remoteDataSource.createSession(
        name: name,
        code: code,
        speakerId: speakerId,
        sourceLanguage: sourceLanguage,
      );

      return Right(session);
    } on SessionNotFoundException catch (e) {
      return Left(ServerFailure(message: e.toString()));
    } catch (e, stackTrace) {
      _logger.e('Failed to create session', error: e, stackTrace: stackTrace);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Session>> getSessionById(String sessionId) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      final session = await _remoteDataSource.getSessionById(sessionId);
      return Right(session);
    } on SessionNotFoundException {
      return const Left(ServerFailure(message: 'Session not found'));
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to get session by ID',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Session>> getSessionByCode(String code) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      final session = await _remoteDataSource.getSessionByCode(code);
      return Right(session);
    } on SessionNotFoundException {
      return const Left(
        ServerFailure(message: 'No active session found with that code'),
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to get session by code',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Session>> joinSession({
    required String sessionId,
    required String userId,
  }) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      final session = await _remoteDataSource.joinSession(
        sessionId: sessionId,
        userId: userId,
      );

      return Right(session);
    } on SessionNotFoundException {
      return const Left(ServerFailure(message: 'Session not found'));
    } catch (e, stackTrace) {
      _logger.e('Failed to join session', error: e, stackTrace: stackTrace);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, Session>> endSession(String sessionId) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      final session = await _remoteDataSource.endSession(sessionId);
      return Right(session);
    } on SessionNotFoundException {
      return const Left(ServerFailure(message: 'Session not found'));
    } catch (e, stackTrace) {
      _logger.e('Failed to end session', error: e, stackTrace: stackTrace);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Session>>> getActiveSessions() async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      final sessions = await _remoteDataSource.getActiveSessions();
      return Right(sessions);
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to get active sessions',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, List<Session>>> getUserSessions(String userId) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      final sessions = await _remoteDataSource.getUserSessions(userId);
      return Right(sessions);
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to get user sessions',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, void>> leaveSession({
    required String sessionId,
    required String userId,
  }) async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      await _remoteDataSource.leaveSession(
        sessionId: sessionId,
        userId: userId,
      );

      return const Right(null);
    } on SessionNotFoundException {
      return const Left(ServerFailure(message: 'Session not found'));
    } catch (e, stackTrace) {
      _logger.e('Failed to leave session', error: e, stackTrace: stackTrace);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Future<Either<Failure, String>> generateSessionCode() async {
    try {
      if (!await _networkChecker.hasConnection()) {
        return const Left(NetworkFailure());
      }

      // Generate a unique, readable code (adjective-noun format)
      const adjectives = [
        'happy',
        'sunny',
        'lucky',
        'brave',
        'bright',
        'clever',
        'mighty',
        'calm',
        'swift',
        'gentle',
      ];

      const nouns = [
        'tiger',
        'eagle',
        'summit',
        'river',
        'ocean',
        'forest',
        'meadow',
        'mountain',
        'star',
        'moon',
      ];

      final random = Random();
      String code;
      bool isUnique = false;

      // Try to generate a unique code
      int attempts = 0;
      do {
        final adjective = adjectives[random.nextInt(adjectives.length)];
        final noun = nouns[random.nextInt(nouns.length)];

        code = '$adjective-$noun';

        // Check if code already exists
        final existing = await _remoteDataSource.checkCodeExists(code);
        isUnique = !existing;

        attempts++;
      } while (!isUnique && attempts < 10);

      if (!isUnique) {
        // Fall back to a random numeric code
        code = (100000 + random.nextInt(900000)).toString();
      }

      return Right(code);
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to generate session code',
        error: e,
        stackTrace: stackTrace,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  @override
  Stream<Either<Failure, Session>> streamSession(String sessionId) {
    try {
      final sessionStream = _remoteDataSource.streamSession(sessionId);

      return sessionStream
          .map<Either<Failure, Session>>((session) => Right(session))
          .handleError((error) {
            if (error is SessionNotFoundException) {
              return Left(ServerFailure(message: 'Session not found'));
            }
            _logger.e('Error streaming session', error: error);
            return Left(ServerFailure(message: error.toString()));
          });
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to set up session stream',
        error: e,
        stackTrace: stackTrace,
      );
      return Stream.value(Left(ServerFailure(message: e.toString())));
    }
  }
}
