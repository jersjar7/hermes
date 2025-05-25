// lib/core/hermes_engine/audience/audience_engine.dart
import 'dart:async';

import 'package:hermes/core/services/logger/logger_service.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';

import '../buffer/translation_buffer.dart';
import '../config/hermes_config.dart';
import '../state/hermes_session_state.dart';
import '../state/hermes_status.dart';
import '../usecases/buffer_management.dart';
import '../usecases/connectivity_handler.dart';
import '../utils/log.dart';

/// Orchestrates audience-side flow: join session, receive translations, buffer, connectivity.
class AudienceEngine {
  final ISessionService _session;
  final ISocketService _socket;
  final IConnectivityService _connectivity;
  final HermesLogger _log;

  // Shared buffer instance, injected
  final TranslationBuffer _buffer;

  // Core state
  HermesSessionState _state = HermesSessionState.initial();
  final _stateController = StreamController<HermesSessionState>.broadcast();
  Stream<HermesSessionState> get stream => _stateController.stream;

  // Helpers
  late final BufferManagementUseCase _bufferMgr;
  late final ConnectivityHandlerUseCase _connHandler;

  AudienceEngine({
    required TranslationBuffer buffer,
    required ISessionService session,
    required ISocketService socket,
    required IConnectivityService connectivity,
    required ILoggerService logger,
  }) : _buffer = buffer,
       _session = session,
       _socket = socket,
       _connectivity = connectivity,
       _log = HermesLogger(logger) {
    _bufferMgr = BufferManagementUseCase(buffer: _buffer, logger: _log);
    _connHandler = ConnectivityHandlerUseCase(
      connectivityService: _connectivity,
      logger: _log,
    );
  }

  /// Starts audience flow: join session and listen for TranslationEvents.
  Future<void> start({required String sessionCode}) async {
    _emit(_state.copyWith(status: HermesStatus.buffering));

    // Join and connect
    await _session.joinSession(sessionCode);
    await _socket.connect(sessionCode);

    _connHandler.startMonitoring(
      onOffline: _handleOffline,
      onOnline: _handleOnline,
    );

    _socket.onEvent.listen((event) {
      if (event is TranslationEvent) {
        _buffer.add(event.translatedText);
        _emit(
          _state.copyWith(
            lastTranslation: event.translatedText,
            buffer: _buffer.all,
          ),
        );

        final ready = _bufferMgr.checkBufferReady();
        if (ready != null) {
          _emit(
            _state.copyWith(
              status: HermesStatus.countdown,
              countdownSeconds: kInitialBufferCountdownSeconds,
            ),
          );
        }
      }
    });
  }

  void _handleOffline() {
    _emit(_state.copyWith(status: HermesStatus.paused));
  }

  void _handleOnline() {
    _emit(_state.copyWith(status: HermesStatus.buffering));
  }

  void _emit(HermesSessionState s) {
    _state = s;
    _stateController.add(s);
  }

  void dispose() {
    _connHandler.dispose();
    _stateController.close();
  }
}
