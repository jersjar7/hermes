// lib/features/session_host/data/datasources/session_remote_datasource.dart

import 'dart:async';

import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/session/session_info.dart' as core;
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/features/session_host/data/models/session_info_model.dart';

/// Wraps the core ISessionService and ISocketService to drive session lifecycle.
class SessionRemoteDataSource {
  final ISessionService _sessionService;
  final ISocketService _socketService;

  SessionRemoteDataSource({
    required ISessionService sessionService,
    required ISocketService socketService,
  }) : _sessionService = sessionService,
       _socketService = socketService;

  /// Starts a new session on the server, then opens the socket channel.
  Future<SessionInfoModel> startSession(String languageCode) async {
    // Use named parameter
    await _sessionService.startSession(languageCode: languageCode);

    // Pull the core SessionInfo
    final core.SessionInfo? coreInfo = _sessionService.currentSession;
    if (coreInfo == null) {
      throw Exception('Failed to start session: no session info available');
    }

    // Open real-time channel for this session
    await _socketService.connect(coreInfo.sessionId);

    // Convert to our feature-domain model
    return SessionInfoModel(
      sessionId: coreInfo.sessionId,
      languageCode: coreInfo.languageCode,
      createdAt: coreInfo.startedAt,
    );
  }

  /// Stops the session on the server and disconnects the socket.
  Future<void> stopSession(String sessionId) async {
    // Core service uses endSession to tear down speaker sessions
    await _sessionService.endSession();
    await _socketService.disconnect();
  }

  /// Retrieves the current session code (for display or sharing).
  Future<String> getSessionCode() async {
    final core.SessionInfo? coreInfo = _sessionService.currentSession;
    if (coreInfo == null) {
      throw Exception('No active session');
    }
    return coreInfo.sessionId;
  }

  /// Exposes a one‐time snapshot of session metadata.
  /// If you need a live stream of state updates, hook into HermesEngine.stream instead.
  Stream<SessionInfoModel> monitorSession(String sessionId) {
    final core.SessionInfo? coreInfo = _sessionService.currentSession;
    if (coreInfo == null) {
      return Stream.error('No active session to monitor');
    }
    return Stream.value(
      SessionInfoModel(
        sessionId: coreInfo.sessionId,
        languageCode: coreInfo.languageCode,
        createdAt: coreInfo.startedAt,
      ),
    );
  }
}
