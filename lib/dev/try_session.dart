import 'package:hermes/core/services/session/session_service_impl.dart';

void main() async {
  final sessionService = SessionServiceImpl();

  print('🎤 Starting session as speaker...');
  await sessionService.startSession(languageCode: 'en-US');
  print('✅ Session started: ${sessionService.currentSession}');

  await Future.delayed(Duration(milliseconds: 500));

  print('⏸️ Pausing session...');
  await sessionService.pauseSession();
  print('🟡 Paused? ${sessionService.isSessionPaused}');

  print('▶️ Resuming session...');
  await sessionService.resumeSession();
  print('🟢 Paused? ${sessionService.isSessionPaused}');

  print('👤 Simulating audience joining...');
  await sessionService.joinSession('ABC123');
  print('🧑 Joined session: ${sessionService.currentSession}');
}
