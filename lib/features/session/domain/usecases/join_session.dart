// lib/features/session/domain/usecases/join_session.dart

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/core/usecases/usecase.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/session/domain/repositories/session_repository.dart';

/// Use case for joining a session
@injectable
class JoinSession implements UseCase<Session, JoinSessionParams> {
  final SessionRepository _repository;

  /// Creates a new [JoinSession] use case
  JoinSession(this._repository);

  @override
  Future<Either<Failure, Session>> call(JoinSessionParams params) async {
    // First get the session by code
    final sessionResult = await _repository.getSessionByCode(
      params.sessionCode,
    );

    return sessionResult.fold((failure) => Left(failure), (session) async {
      // Then join the session
      return await _repository.joinSession(
        sessionId: session.id,
        userId: params.userId,
      );
    });
  }
}

/// Parameters for joining a session
class JoinSessionParams extends Equatable {
  /// Session code to join
  final String sessionCode;

  /// ID of the user joining
  final String userId;

  /// Creates new [JoinSessionParams]
  const JoinSessionParams({required this.sessionCode, required this.userId});

  @override
  List<Object> get props => [sessionCode, userId];
}
