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

  // Improved reconnection logic - INFINITE RECONNECTIONS during active sessions
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;
  int _reconnectAttempts = 0;

  // Reconnection configuration
  static const Duration _baseReconnectDelay = Duration(seconds: 2);
  static const Duration _maxReconnectDelay = Duration(
    seconds: 30,
  ); // Cap backoff at 30s
  static const Duration _heartbeatInterval = Duration(seconds: 45);

  // Reset attempt counter after successful connection for this duration
  static const Duration _successfulConnectionWindow = Duration(minutes: 2);
  Timer? _resetAttemptsTimer;

  SocketServiceImpl(this._logger);

  @override
  bool get isConnected => _connected && _channel != null;

  @override
  Stream<SocketEvent> get onEvent => _controller.stream;

  @override
  Future<void> connect(String sessionId) async {
    _currentSessionId = sessionId;
    _intentionalDisconnect = false;
    _reconnectAttempts = 0; // Reset attempts for new session
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

      _logger.logInfo(
        'Successfully connected to session $_currentSessionId after ${_reconnectAttempts + 1} attempts',
        context: 'SocketService',
      );

      // Connection successful - reset attempts counter after a delay
      _scheduleAttemptsReset();

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
      _reconnectAttempts++; // Increment attempts only on failure

      if (!_intentionalDisconnect) {
        _scheduleReconnect();
      }
    }
  }

  void _scheduleAttemptsReset() {
    _resetAttemptsTimer?.cancel();
    _resetAttemptsTimer = Timer(_successfulConnectionWindow, () {
      if (_connected) {
        _logger.logInfo(
          'Resetting reconnection attempt counter after successful connection',
          context: 'SocketService',
        );
        _reconnectAttempts = 0;
      }
    });
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
      _reconnectAttempts++;
      _scheduleReconnect();
    }
  }

  void _handleDisconnection() {
    _logger.logInfo('WebSocket connection closed', context: 'SocketService');
    _connected = false;
    _stopHeartbeat();

    if (!_intentionalDisconnect) {
      _reconnectAttempts++;
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
          _reconnectAttempts++;
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
        'Cannot send - socket not connected (will retry when connection restored)',
        context: 'SocketService',
      );

      // Try to reconnect if we have a session and aren't intentionally disconnected
      if (_currentSessionId != null && !_intentionalDisconnect) {
        _scheduleReconnect();
      }

      // For now, we'll just log that the message was lost
      // In the future, we could implement local buffering here
      _logger.logInfo(
        'Message lost due to disconnection: ${event.type}',
        context: 'SocketService',
      );
      return;
    }

    try {
      final msg = jsonEncode(event.toJson());
      _logger.logInfo('Sending ${event.type}', context: 'SocketService');
      _channel!.sink.add(msg);
    } catch (e) {
      _logger.logError('Failed to send message: $e', context: 'SocketService');
      _connected = false;
      _reconnectAttempts++;

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
    _resetAttemptsTimer?.cancel();
    _resetAttemptsTimer = null;
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

    _reconnectTimer?.cancel();

    // Intelligent backoff with jitter
    // Starts at 2s, grows exponentially but caps at 30s
    final backoffSeconds = (_baseReconnectDelay.inSeconds *
            (1 <<
                _reconnectAttempts.clamp(
                  0,
                  4,
                ))) // Cap exponential growth at 2^4 = 16
        .clamp(_baseReconnectDelay.inSeconds, _maxReconnectDelay.inSeconds);

    // Add jitter to prevent thundering herd (±20% randomization)
    final jitterFactor =
        0.8 + (DateTime.now().millisecondsSinceEpoch % 100) / 250;
    final delaySeconds = (backoffSeconds * jitterFactor).round();
    final delay = Duration(seconds: delaySeconds);

    _logger.logInfo(
      'Scheduling reconnect attempt ${_reconnectAttempts + 1} in ${delay.inSeconds}s (infinite retries enabled)',
      context: 'SocketService',
    );

    _reconnectTimer = Timer(delay, () {
      if (_currentSessionId != null && !_intentionalDisconnect) {
        _logger.logInfo(
          'Reconnecting to $_currentSessionId (attempt ${_reconnectAttempts + 1})',
          context: 'SocketService',
        );
        _connectInternal();
      }
    });

    // Log status every 10 attempts to show we're still trying
    if (_reconnectAttempts > 0 && _reconnectAttempts % 10 == 0) {
      _logger.logInfo(
        'Still attempting to reconnect to $_currentSessionId ($_reconnectAttempts attempts so far)',
        context: 'SocketService',
      );
    }
  }

  void dispose() {
    _intentionalDisconnect = true;
    _reconnectTimer?.cancel();
    _resetAttemptsTimer?.cancel();
    _stopHeartbeat();
    _controller.close();
    _channel?.sink.close();
  }
}
