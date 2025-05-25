//lib/core/services/socket/socket_service_impl.dart
import 'dart:async';
import 'package:hermes/core/services/logger/logger_service.dart';
import 'socket_service.dart';
import 'socket_event.dart';

class SocketServiceImpl implements ISocketService {
  final _controller = StreamController<SocketEvent>.broadcast();
  final ILoggerService _logger;
  bool _connected = false;

  SocketServiceImpl(this._logger);

  @override
  bool get isConnected => _connected;

  @override
  Stream<SocketEvent> get onEvent => _controller.stream;

  @override
  Future<void> connect(String sessionId) async {
    _connected = true;
    _logger.logInfo('Connected to $sessionId', context: 'SocketService');
    // actual WebSocket hookup goes here
  }

  @override
  Future<void> send(SocketEvent event) async {
    _logger.logInfo('Emitting ${event.runtimeType}', context: 'SocketService');
    _controller.add(event);
  }

  @override
  Future<void> disconnect() async {
    _connected = false;
    _logger.logInfo('Disconnected', context: 'SocketService');
    await _controller.close();
  }
}
