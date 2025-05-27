// lib/core/services/session/session_service.dart
import 'session_info.dart';

abstract class ISessionService {
  Future<void> startSession({required String languageCode});
  Future<void> endSession();
  Future<void> pauseSession();
  Future<void> resumeSession();

  Future<void> joinSession(String sessionCode);
  Future<void> leaveSession();

  bool get isSpeaker;
  bool get isSessionActive;
  bool get isSessionPaused;

  SessionInfo? get currentSession;
}
