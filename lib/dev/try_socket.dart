import 'package:hermes/core/services/socket/socket_service_impl.dart';
import 'package:hermes/core/services/socket/socket_event.dart';

void main() async {
  final socket = SocketServiceImpl();
  await socket.connect('dev-session');

  socket.onEvent.listen((event) {
    if (event is TranscriptEvent) {
      print('🟢 Transcript received: ${event.text} | Final: ${event.isFinal}');
    } else if (event is TranslationEvent) {
      print('🌍 Translation received: ${event.translatedText}');
    }
  });

  final event = TranscriptEvent(
    sessionId: 'dev-session',
    text: 'Hello from the socket!',
    isFinal: false,
  );

  print('📤 Sending TranscriptEvent...');
  await socket.send(event);
}
