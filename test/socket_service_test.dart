import 'package:flutter_test/flutter_test.dart';
import 'package:hermes/core/services/socket/socket_event.dart';
import 'package:hermes/core/services/socket/socket_service_impl.dart';

void main() {
  group('SocketServiceImpl', () {
    final socket = SocketServiceImpl();

    test('connects and sends TranscriptEvent', () async {
      await socket.connect('session-123');
      expect(socket.isConnected, isTrue);

      final events = <SocketEvent>[];
      final sub = socket.onEvent.listen(events.add);

      final testEvent = TranscriptEvent(
        sessionId: 'session-123',
        text: 'Testing socket',
        isFinal: true,
      );

      await socket.send(testEvent);
      await Future.delayed(Duration(milliseconds: 50));

      expect(events.length, 1);
      expect(events.first, isA<TranscriptEvent>());
      expect((events.first as TranscriptEvent).text, 'Testing socket');

      await sub.cancel();
      await socket.disconnect();
      expect(socket.isConnected, isFalse);
    });
  });
}
