// lib/features/session/domain/repositories/session_repository.dart

import 'package:dartz/dartz.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/features/session/domain/entities/session.dart';

/// Repository interface for session operations
abstract class SessionRepository {
  /// Create a new session
  Future<Either<Failure, Session>> createSession({
    required String name,
    required String speakerId,
    required String sourceLanguage,
  });

  /// Get a session by ID
  Future<Either<Failure, Session>> getSessionById(String sessionId);

  /// Get a session by code
  Future<Either<Failure, Session>> getSessionByCode(String code);

  /// Join a session
  Future<Either<Failure, Session>> joinSession({
    required String sessionId,
    required String userId,
  });

  /// End a session
  Future<Either<Failure, Session>> endSession(String sessionId);

  /// Get active sessions
  Future<Either<Failure, List<Session>>> getActiveSessions();

  /// Get user's sessions (as speaker)
  Future<Either<Failure, List<Session>>> getUserSessions(String userId);

  /// Leave a session (for audience)
  Future<Either<Failure, void>> leaveSession({
    required String sessionId,
    required String userId,
  });

  /// Generate a unique session code
  Future<Either<Failure, String>> generateSessionCode();

  /// Stream updates for a session
  Stream<Either<Failure, Session>> streamSession(String sessionId);
}
