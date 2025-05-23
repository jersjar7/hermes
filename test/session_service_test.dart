import 'package:flutter_test/flutter_test.dart';
import 'package:hermes/core/services/session/session_service_impl.dart';

void main() {
  group('SessionServiceImpl', () {
    final sessionService = SessionServiceImpl();

    test('starts a session and sets speaker role', () async {
      await sessionService.startSession(languageCode: 'en-US');
      expect(sessionService.isSessionActive, isTrue);
      expect(sessionService.isSpeaker, isTrue);
      expect(sessionService.currentSession!.languageCode, equals('en-US'));
    });

    test('pauses and resumes session', () async {
      await sessionService.startSession(languageCode: 'en-US');
      await sessionService.pauseSession();
      expect(sessionService.isSessionPaused, isTrue);

      await sessionService.resumeSession();
      expect(sessionService.isSessionPaused, isFalse);
    });

    test('joins and leaves session as audience', () async {
      await sessionService.joinSession('XYZ123');
      expect(sessionService.isSpeaker, isFalse);
      expect(sessionService.currentSession!.sessionId, equals('XYZ123'));

      await sessionService.leaveSession();
      expect(sessionService.isSessionActive, isFalse);
    });
  });
}
