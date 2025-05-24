import 'package:flutter_test/flutter_test.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';

void main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();

  final sessionService = getIt<ISessionService>();

  group('SessionServiceImpl', () {
    test('starts a session and sets speaker role', () async {
      await sessionService.startSession(languageCode: 'en-US');
      expect(sessionService.isSessionActive, isTrue);
      expect(sessionService.isSpeaker, isTrue);
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
