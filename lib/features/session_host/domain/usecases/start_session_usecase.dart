// lib/features/session_host/domain/usecases/start_session_usecase.dart

import 'package:hermes/features/session_host/domain/repositories/session_repository.dart';

/// Use-case for starting a new session and obtaining its code.
class StartSessionUseCase {
  final SessionRepository _sessionRepository;

  StartSessionUseCase(this._sessionRepository);

  /// Starts a session with the given [languageCode]
  /// and returns the generated session code.
  Future<String> execute(String languageCode) async {
    final sessionInfo = await _sessionRepository.startSession(languageCode);
    return sessionInfo.sessionId;
  }
}
