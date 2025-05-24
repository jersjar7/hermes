import 'dart:async';
import 'package:hermes/core/services/logger/logger_service.dart';
import 'socket_service.dart';
import 'socket_event.dart';

class SocketServiceImpl implements ISocketService {
  final _eventController = StreamController<SocketEvent>.broadcast();
  final ILoggerService _logger;

  bool _connected = false;

  SocketServiceImpl(this._logger);

  @override
  bool get isConnected => _connected;

  @override
  Stream<SocketEvent> get onEvent => _eventController.stream;

  @override
  Future<void> connect(String sessionId) async {
    _connected = true;
    _logger.logInfo(
      'Connected to session $sessionId',
      context: 'SocketService',
    );
    // TODO: connect to WebSocket backend using sessionId
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _logger.logInfo('Disconnected from socket', context: 'SocketService');
    await _eventController.close();
  }

  @override
  Future<void> send(SocketEvent event) async {
    _logger.logInfo(
      'Sending event: ${event.runtimeType}',
      context: 'SocketService',
    );
    _eventController.add(event); // Simulated local echo
  }
}
