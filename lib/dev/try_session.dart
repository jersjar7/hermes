import 'package:flutter/widgets.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();

  final sessionService = getIt<ISessionService>();

  await sessionService.startSession(languageCode: 'en-US');
  await Future.delayed(Duration(milliseconds: 500));
  await sessionService.pauseSession();
  await sessionService.resumeSession();
  await sessionService.joinSession('ABC123');
}
