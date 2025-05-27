// lib/dev/try_socket.dart

import 'package:flutter/widgets.dart';
import 'package:get_it/get_it.dart';

import '../core/service_locator.dart';
import '../core/services/socket/socket_service.dart';
import '../core/services/socket/socket_event.dart'; // import your events

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await setupServiceLocator();

  final socket = GetIt.I<ISocketService>();

  // Listen for any incoming socket events
  socket.onEvent.listen((e) {
    if (e is TranscriptEvent) {
      print(
        '→ TranscriptEvent: session=${e.sessionId}, text="${e.text}", isFinal=${e.isFinal}',
      );
    } else if (e is TranslationEvent) {
      print(
        '→ TranslationEvent: session=${e.sessionId}, text="${e.translatedText}", lang=${e.targetLanguage}',
      );
    } else {
      print('→ Unknown event: $e');
    }
  });

  print('Connecting…');
  await socket.connect('TEST_SESSION');

  // Send a test transcript event
  await socket.send(
    TranscriptEvent(
      sessionId: 'TEST_SESSION',
      text: 'Hello, world!',
      isFinal: true,
    ),
  );

  // Keep the runner alive for a few seconds to see replies
  await Future.delayed(const Duration(seconds: 5));

  await socket.disconnect();
  print('Disconnected.');
}
