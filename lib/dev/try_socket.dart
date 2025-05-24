import 'package:flutter/widgets.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();

  final socket = getIt<ISocketService>();
  await socket.connect('dev-session');

  socket.onEvent.listen((event) {
    if (event is TranscriptEvent) {
      print('🟢 Transcript received: ${event.text} | Final: ${event.isFinal}');
    } else if (event is TranslationEvent) {
      print('🌍 Translation received: ${event.translatedText}');
    }
  });

  await socket.send(
    TranscriptEvent(
      sessionId: 'dev-session',
      text: 'Hello from the socket!',
      isFinal: false,
    ),
  );
}
