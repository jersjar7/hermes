// lib/features/session/domain/usecases/end_session.dart

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/core/usecases/usecase.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/session/domain/repositories/session_repository.dart';

/// Use case for ending a session
class EndSession implements UseCase<Session, EndSessionParams> {
  final SessionRepository _repository;

  /// Creates a new [EndSession] use case
  EndSession(this._repository);

  @override
  Future<Either<Failure, Session>> call(EndSessionParams params) async {
    return await _repository.endSession(params.sessionId);
  }
}

/// Parameters for ending a session
class EndSessionParams extends Equatable {
  /// ID of the session to end
  final String sessionId;

  /// Creates new [EndSessionParams]
  const EndSessionParams({required this.sessionId});

  @override
  List<Object> get props => [sessionId];
}
