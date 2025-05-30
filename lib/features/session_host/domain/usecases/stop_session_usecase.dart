// lib/features/session_host/domain/usecases/stop_session_usecase.dart

import 'package:hermes/features/session_host/domain/repositories/session_repository.dart';

/// Use-case for ending the current session and cleaning up resources.
class StopSessionUseCase {
  final SessionRepository _sessionRepository;

  StopSessionUseCase(this._sessionRepository);

  /// Stops the session identified by [sessionId].
  Future<void> execute(String sessionId) async {
    await _sessionRepository.stopSession(sessionId);
  }
}
