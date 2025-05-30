import 'package:flutter/widgets.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator(); // ✅ Full service registration

  final sessionService = getIt<ISessionService>();

  print('🎤 Starting session as speaker...');
  await sessionService.startSession(languageCode: 'en-US');

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
