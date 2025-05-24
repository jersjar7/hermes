import 'package:flutter/widgets.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/session/session_service_impl.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  setupServiceLocator();

  final speakerSession = getIt<ISessionService>();
  final audienceSession = SessionServiceImpl(
    socketService: getIt(),
    sttService: getIt(),
    translationService: getIt(),
    ttsService: getIt(),
  );

  print('🎤 Starting speaker session...');
  await speakerSession.startSession(languageCode: 'es');
  final sessionId = speakerSession.currentSession!.sessionId;

  print('👥 Audience joining session: $sessionId');
  await audienceSession.joinSession(sessionId);

  print('💬 Manually simulating transcribed speech...');
  await Future.delayed(Duration(seconds: 2));

  final fakeTranscript = 'Hello, how are you?';
  print('🎙️ Injected: $fakeTranscript');

  await getIt<ISocketService>().send(
    TranslationEvent(
      sessionId: sessionId,
      translatedText: 'Hola, ¿cómo estás?',
      targetLanguage: 'es',
    ),
  );

  print('⏳ Waiting for audience to receive and speak...');
  await Future.delayed(Duration(seconds: 5));

  print('🛑 Ending speaker session...');
  await speakerSession.endSession();
  print('👤 Audience leaving...');
  await audienceSession.leaveSession();
}
