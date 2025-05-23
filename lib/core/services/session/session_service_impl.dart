import 'dart:math';

import 'session_info.dart';
import 'session_service.dart';

class SessionServiceImpl implements ISessionService {
  SessionInfo? _session;
  bool _isSpeaker = false;

  @override
  bool get isSpeaker => _isSpeaker;

  @override
  bool get isSessionActive => _session != null;

  @override
  bool get isSessionPaused => _session?.isPaused ?? false;

  @override
  SessionInfo? get currentSession => _session;

  @override
  Future<void> startSession({required String languageCode}) async {
    final sessionId = _generateSessionCode();
    _session = SessionInfo(
      sessionId: sessionId,
      languageCode: languageCode,
      startedAt: DateTime.now(),
    );
    _isSpeaker = true;
  }

  @override
  Future<void> endSession() async {
    _session = null;
    _isSpeaker = false;
  }

  @override
  Future<void> pauseSession() async {
    if (_session != null) {
      _session = _session!.copyWith(isPaused: true);
    }
  }

  @override
  Future<void> resumeSession() async {
    if (_session != null) {
      _session = _session!.copyWith(isPaused: false);
    }
  }

  @override
  Future<void> joinSession(String sessionCode) async {
    _session = SessionInfo(
      sessionId: sessionCode,
      languageCode: 'en-US', // default or resolved later
      startedAt: DateTime.now(),
    );
    _isSpeaker = false;
  }

  @override
  Future<void> leaveSession() async {
    _session = null;
    _isSpeaker = false;
  }

  String _generateSessionCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
