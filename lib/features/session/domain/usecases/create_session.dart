// lib/features/session/domain/usecases/create_session.dart

import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import 'package:injectable/injectable.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/core/usecases/usecase.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/session/domain/repositories/session_repository.dart';

/// Use case for creating a new session
@injectable
class CreateSession implements UseCase<Session, CreateSessionParams> {
  final SessionRepository _repository;

  /// Creates a new [CreateSession] use case
  CreateSession(this._repository);

  @override
  Future<Either<Failure, Session>> call(CreateSessionParams params) async {
    return await _repository.createSession(
      name: params.name,
      speakerId: params.speakerId,
      sourceLanguage: params.sourceLanguage,
    );
  }
}

/// Parameters for creating a session
class CreateSessionParams extends Equatable {
  /// Name of the session
  final String name;

  /// ID of the speaker
  final String speakerId;

  /// Source language code
  final String sourceLanguage;

  /// Creates new [CreateSessionParams]
  const CreateSessionParams({
    required this.name,
    required this.speakerId,
    required this.sourceLanguage,
  });

  @override
  List<Object> get props => [name, speakerId, sourceLanguage];
}
