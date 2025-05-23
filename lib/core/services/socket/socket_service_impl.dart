import 'dart:async';
import 'socket_service.dart';
import 'socket_event.dart';

class SocketServiceImpl implements ISocketService {
  final _eventController = StreamController<SocketEvent>.broadcast();
  bool _connected = false;

  @override
  bool get isConnected => _connected;

  @override
  Stream<SocketEvent> get onEvent => _eventController.stream;

  @override
  Future<void> connect(String sessionId) async {
    _connected = true;
    // TODO: connect to WebSocket backend using sessionId
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    await _eventController.close();
  }

  @override
  Future<void> send(SocketEvent event) async {
    // Simulate sending + echo for local dev
    _eventController.add(event);
  }
}
