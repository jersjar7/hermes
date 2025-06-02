// lib/core/services/session/session_service_impl.dart
import 'dart:math';

import 'session_info.dart';
import 'session_service.dart';
import '../logger/logger_service.dart';

class SessionServiceImpl implements ISessionService {
  final ILoggerService _logger;

  SessionInfo? _session;
  bool _isSpeaker = false;

  SessionServiceImpl({required ILoggerService logger}) : _logger = logger;

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

    _logger.logInfo(
      'Session created: $sessionId (socket connection deferred until Go Live)',
      context: 'SessionService',
    );

    // 🎯 KEY CHANGE: No socket connection here!
    // Socket will be connected when speaker actually goes live
  }

  @override
  Future<void> joinSession(String sessionCode) async {
    _session = SessionInfo(
      sessionId: sessionCode,
      languageCode: _session?.languageCode ?? 'en-US',
      startedAt: DateTime.now(),
    );
    _isSpeaker = false;

    _logger.logInfo(
      'Joined session: $sessionCode (audience mode)',
      context: 'SessionService',
    );

    // Note: Audience will connect socket when joining active session page
  }

  @override
  Future<void> pauseSession() async {
    if (_session != null) {
      _session = _session!.copyWith(isPaused: true);
      _logger.logInfo('Session paused', context: 'SessionService');
    }
  }

  @override
  Future<void> resumeSession() async {
    if (_session != null) {
      _session = _session!.copyWith(isPaused: false);
      _logger.logInfo('Session resumed', context: 'SessionService');
    }
  }

  @override
  Future<void> endSession() async {
    if (_session != null) {
      _logger.logInfo(
        'Session ${_session!.sessionId} ended',
        context: 'SessionService',
      );
    }

    _session = null;
    _isSpeaker = false;
  }

  @override
  Future<void> leaveSession() async {
    if (_session != null) {
      _logger.logInfo(
        'Left session ${_session!.sessionId}',
        context: 'SessionService',
      );
    }

    _session = null;
    _isSpeaker = false;
  }

  String _generateSessionCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
