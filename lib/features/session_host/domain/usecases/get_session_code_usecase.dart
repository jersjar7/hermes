// lib/features/session_host/domain/usecases/get_session_code_usecase.dart

import 'package:hermes/features/session_host/domain/repositories/session_repository.dart';

/// Use-case for retrieving the current session’s join code.
class GetSessionCodeUseCase {
  final SessionRepository _sessionRepository;

  GetSessionCodeUseCase(this._sessionRepository);

  /// Returns the active session’s [sessionId].
  Future<String> execute() async {
    return await _sessionRepository.getSessionCode();
  }
}
