import 'socket_event.dart';

abstract class ISocketService {
  /// Connects to the socket server.
  Future<void> connect(String sessionId);

  /// Disconnects from the socket.
  Future<void> disconnect();

  /// Sends an event to the socket.
  Future<void> send(SocketEvent event);

  /// Returns a stream of events received from the socket.
  Stream<SocketEvent> get onEvent;

  /// Returns true if currently connected.
  bool get isConnected;
}
