// lib/core/services/socket/socket_service.dart
import 'socket_event.dart';

/// Abstracts your WebSocket so you never deal
/// with channel/sink/stream directly in the engine.
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
