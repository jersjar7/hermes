// lib/features/session/domain/usecases/get_active_sessions.dart

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/core/usecases/usecase.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/session/domain/repositories/session_repository.dart';

/// Use case for getting active sessions
@injectable
class GetActiveSessions implements NoParamsUseCase<List<Session>> {
  final SessionRepository _repository;

  /// Creates a new [GetActiveSessions] use case
  GetActiveSessions(this._repository);

  @override
  Future<Either<Failure, List<Session>>> call() async {
    return await _repository.getActiveSessions();
  }
}
