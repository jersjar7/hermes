// lib/features/session_host/domain/usecases/monitor_session_usecase.dart

import 'package:hermes/features/session_host/domain/entities/session_info.dart';
import 'package:hermes/features/session_host/domain/repositories/session_repository.dart';

/// Use-case for observing live updates to a session’s state.
class MonitorSessionUseCase {
  final SessionRepository _sessionRepository;

  MonitorSessionUseCase(this._sessionRepository);

  /// Returns a [Stream] of [SessionInfo] updates for the given [sessionId].
  Stream<SessionInfo> execute(String sessionId) {
    return _sessionRepository.monitorSession(sessionId);
  }
}
