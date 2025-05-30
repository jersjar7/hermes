// lib/features/session_host/domain/repositories/session_repository.dart

import 'package:hermes/features/session_host/domain/entities/session_info.dart';

/// Defines the contract for session lifecycle operations.
abstract class SessionRepository {
  /// Starts a new speaking session with the chosen [languageCode].
  ///
  /// Returns a [SessionInfo] containing the generated sessionId and metadata.
  Future<SessionInfo> startSession(String languageCode);

  /// Stops the session identified by [sessionId], tearing down sockets/resources.
  Future<void> stopSession(String sessionId);

  /// Retrieves the current session’s code (sessionId) for display or sharing.
  Future<String> getSessionCode();

  /// Emits updates to the session state (e.g. buffering, live) for [sessionId].
  Stream<SessionInfo> monitorSession(String sessionId);
}
