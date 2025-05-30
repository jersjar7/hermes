import 'package:flutter/widgets.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';
import 'package:hermes/core/services/socket/socket_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();

  final speakerSession = getIt<ISessionService>();
  final audienceSession =
      getIt<ISessionService>(); // cleaner than manual instantiation

  await speakerSession.startSession(languageCode: 'es');
  final sessionId = speakerSession.currentSession!.sessionId;

  await audienceSession.joinSession(sessionId);

  await Future.delayed(Duration(seconds: 2));

  await getIt<ISocketService>().send(
    TranslationEvent(
      sessionId: sessionId,
      translatedText: 'Hola, ¿cómo estás?',
      targetLanguage: 'es',
    ),
  );

  await Future.delayed(Duration(seconds: 5));
  await speakerSession.endSession();
  await audienceSession.leaveSession();
}
