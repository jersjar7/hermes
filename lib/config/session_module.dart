// lib/config/session_module.dart

import 'package:firebase_auth/firebase_auth.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:injectable/injectable.dart';
import 'package:hermes/features/session/domain/usecases/create_session.dart';
import 'package:hermes/features/session/domain/usecases/join_session.dart';
import 'package:hermes/features/session/domain/usecases/end_session.dart';
import 'package:hermes/features/session/domain/usecases/get_active_sessions.dart';
import 'package:hermes/features/session/infrastructure/services/auth_service.dart';
import 'package:hermes/features/session/domain/repositories/session_repository.dart';

@module
abstract class SessionInjectableModule {
  @lazySingleton
  CreateSession createSession(SessionRepository repository) =>
      CreateSession(repository);

  @lazySingleton
  JoinSession joinSession(SessionRepository repository) =>
      JoinSession(repository);

  @lazySingleton
  EndSession endSession(SessionRepository repository) => EndSession(repository);

  @lazySingleton
  GetActiveSessions getActiveSessions(SessionRepository repository) =>
      GetActiveSessions(repository);

  @lazySingleton
  AuthService authService(FirebaseAuth auth, Logger logger) =>
      AuthService(auth, logger);
}
