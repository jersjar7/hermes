// lib/core/services/socket/socket_service_impl.dart

import 'dart:async';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import 'package:hermes/core/services/logger/logger_service.dart';
import 'package:hermes/core/hermes_engine/config/hermes_config.dart';

import 'socket_service.dart';
import 'socket_event.dart';

class SocketServiceImpl implements ISocketService {
  final ILoggerService _logger;
  WebSocketChannel? _channel;
  final _controller = StreamController<SocketEvent>.broadcast();
  bool _connected = false;
  String? _currentSessionId;

  SocketServiceImpl(this._logger);

  @override
  bool get isConnected => _connected;

  @override
  Stream<SocketEvent> get onEvent => _controller.stream;

  @override
  Future<void> connect(String sessionId) async {
    _currentSessionId = sessionId;
    final uri = Uri.parse('$kWebSocketBaseUrl/ws/$sessionId');
    _logger.logInfo(
      'Connecting to WebSocket at $uri',
      context: 'SocketService',
    );

    _channel = WebSocketChannel.connect(uri);
    _connected = true;
    _logger.logInfo(
      'Connected to session $sessionId',
      context: 'SocketService',
    );

    _channel!.stream.listen(
      (raw) {
        try {
          final evt = SocketEvent.decode(raw as String);
          _controller.add(evt);
        } catch (err, st) {
          _logger.logError(
            'WS parse error: $err',
            context: 'SocketService',
            stackTrace: st,
          );
          _controller.addError(err);
        }
      },
      onError: (err) {
        _logger.logError('WebSocket error: $err', context: 'SocketService');
        _controller.addError(err);
      },
      onDone: () {
        _logger.logInfo('WebSocket closed by server', context: 'SocketService');
        _connected = false;
        _scheduleReconnect();
      },
      cancelOnError: true,
    );
  }

  @override
  Future<void> send(SocketEvent event) async {
    if (_channel == null) {
      throw StateError('Cannot send — socket not connected');
    }
    final msg = jsonEncode(event.toJson());
    _logger.logInfo('Sending ${event.type}: $msg', context: 'SocketService');
    _channel!.sink.add(msg);
  }

  @override
  Future<void> disconnect() async {
    _logger.logInfo('Disconnecting WebSocket', context: 'SocketService');
    _connected = false;
    _currentSessionId = null;
    await _channel?.sink.close(status.normalClosure);
    // leave _controller open for possible reconnects
  }

  void _scheduleReconnect() {
    if (_currentSessionId == null) return;
    Future.delayed(const Duration(seconds: 2), () {
      _logger.logInfo(
        'Reconnecting to $_currentSessionId',
        context: 'SocketService',
      );
      connect(_currentSessionId!);
    });
  }

  /// Call this when the app is shutting down.
  void dispose() {
    _controller.close();
    _channel?.sink.close();
  }
}
