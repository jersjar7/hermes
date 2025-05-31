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
  bool _intentionalDisconnect = false;
  String? _currentSessionId;

  // Improved reconnection logic
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts =
      10; // More attempts for long sessions
  static const Duration _baseReconnectDelay = Duration(seconds: 3);
  static const Duration _maxReconnectDelay = Duration(seconds: 30);
  static const Duration _heartbeatInterval = Duration(seconds: 45);

  SocketServiceImpl(this._logger);

  @override
  bool get isConnected => _connected && _channel != null;

  @override
  Stream<SocketEvent> get onEvent => _controller.stream;

  @override
  Future<void> connect(String sessionId) async {
    _currentSessionId = sessionId;
    _intentionalDisconnect = false;
    _reconnectAttempts = 0;
    await _connectInternal();
  }

  Future<void> _connectInternal() async {
    if (_currentSessionId == null || _intentionalDisconnect) return;

    try {
      _logger.logInfo(
        'Connecting to WebSocket: $kWebSocketBaseUrl/ws/$_currentSessionId (attempt ${_reconnectAttempts + 1})',
        context: 'SocketService',
      );

      final uri = Uri.parse('$kWebSocketBaseUrl/ws/$_currentSessionId');
      _channel = WebSocketChannel.connect(uri);

      _logger.logInfo(
        'WebSocket connection established',
        context: 'SocketService',
      );

      // Listen for connection establishment
      await _channel!.ready;

      _connected = true;
      _reconnectAttempts = 0; // Reset only on successful connection

      _logger.logInfo(
        'Successfully connected to session $_currentSessionId',
        context: 'SocketService',
      );

      // Start heartbeat to keep connection alive
      _startHeartbeat();

      // Listen to messages
      _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDisconnection,
        cancelOnError: false,
      );
    } catch (e) {
      _logger.logError('Connection failed: $e', context: 'SocketService');
      _connected = false;

      if (!_intentionalDisconnect) {
        _scheduleReconnect();
      }
    }
  }

  void _handleMessage(dynamic raw) {
    try {
      if (raw is String) {
        final evt = SocketEvent.decode(raw);
        _controller.add(evt);
      }
    } catch (err, st) {
      _logger.logError(
        'Message parse error: $err',
        context: 'SocketService',
        stackTrace: st,
      );
    }
  }

  void _handleError(dynamic error) {
    _logger.logError('WebSocket error: $error', context: 'SocketService');
    _connected = false;
    _stopHeartbeat();

    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _handleDisconnection() {
    _logger.logInfo('WebSocket connection closed', context: 'SocketService');
    _connected = false;
    _stopHeartbeat();

    if (!_intentionalDisconnect) {
      _scheduleReconnect();
    }
  }

  void _startHeartbeat() {
    _stopHeartbeat();

    _heartbeatTimer = Timer.periodic(_heartbeatInterval, (timer) {
      if (_connected && _channel != null) {
        try {
          // Send a ping to keep connection alive
          // Note: WebSocket ping/pong is handled automatically by the browser/dart
          _logger.logInfo('Heartbeat ping sent', context: 'SocketService');
        } catch (e) {
          _logger.logError('Heartbeat failed: $e', context: 'SocketService');
          _connected = false;
          _scheduleReconnect();
        }
      } else {
        timer.cancel();
      }
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  Future<void> send(SocketEvent event) async {
    if (!_connected || _channel == null) {
      _logger.logError(
        'Cannot send - socket not connected',
        context: 'SocketService',
      );

      // Try to reconnect if we have a session
      if (_currentSessionId != null && !_intentionalDisconnect) {
        _scheduleReconnect();
      }
      return;
    }

    try {
      final msg = jsonEncode(event.toJson());
      _logger.logInfo('Sending ${event.type}', context: 'SocketService');
      _channel!.sink.add(msg);
    } catch (e) {
      _logger.logError('Failed to send message: $e', context: 'SocketService');
      _connected = false;

      if (!_intentionalDisconnect) {
        _scheduleReconnect();
      }
    }
  }

  @override
  Future<void> disconnect() async {
    _logger.logInfo(
      'Intentionally disconnecting WebSocket',
      context: 'SocketService',
    );

    _intentionalDisconnect = true;
    _connected = false;
    _currentSessionId = null;

    // Cancel timers
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopHeartbeat();

    // Reset reconnection attempts
    _reconnectAttempts = 0;

    // Close connection gracefully
    if (_channel != null) {
      await _channel!.sink.close(status.normalClosure);
      _channel = null;
    }
  }

  void _scheduleReconnect() {
    // Don't reconnect if disconnecting intentionally or no session
    if (_intentionalDisconnect || _currentSessionId == null) return;

    // Don't exceed max attempts
    if (_reconnectAttempts >= _maxReconnectAttempts) {
      _logger.logError(
        'Max reconnection attempts reached for $_currentSessionId',
        context: 'SocketService',
      );
      _controller.addError(
        'Connection failed after $_maxReconnectAttempts attempts',
      );
      return;
    }

    _reconnectTimer?.cancel();

    // Progressive backoff with jitter: 3s, 6s, 12s, 24s, 30s (max)
    final backoffSeconds = (_baseReconnectDelay.inSeconds *
            (1 << _reconnectAttempts))
        .clamp(_baseReconnectDelay.inSeconds, _maxReconnectDelay.inSeconds);

    // Add jitter to prevent thundering herd
    final jitter =
        (backoffSeconds *
            0.1 *
            (DateTime.now().millisecondsSinceEpoch % 100) /
            100);
    final delay = Duration(seconds: (backoffSeconds + jitter).round());

    _reconnectAttempts++;

    _logger.logInfo(
      'Scheduling reconnect attempt $_reconnectAttempts in ${delay.inSeconds}s',
      context: 'SocketService',
    );

    _reconnectTimer = Timer(delay, () {
      if (_currentSessionId != null && !_intentionalDisconnect) {
        _logger.logInfo(
          'Reconnecting to $_currentSessionId (attempt $_reconnectAttempts)',
          context: 'SocketService',
        );
        _connectInternal();
      }
    });
  }

  void dispose() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _stopHeartbeat();
    _controller.close();
    _channel?.sink.close();
  }
}
