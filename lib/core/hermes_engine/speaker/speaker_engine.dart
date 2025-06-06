// lib/core/hermes_engine/speaker/speaker_engine.dart
// SIMPLIFIED: Removed pattern detection, only handles continuous partials

import 'dart:async';

import 'package:hermes/core/services/logger/logger_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';

import '../state/hermes_session_state.dart';
import '../state/hermes_status.dart';
import '../usecases/start_session.dart';
import '../usecases/connectivity_handler.dart';
import '../utils/log.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service.dart';
import 'package:hermes/core/services/speech_to_text/speech_result.dart';
import 'package:hermes/core/services/translation/translation_service.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/permission/permission_service.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';

/// Simplified SpeakerEngine that only handles continuous partial results
/// Buffer-based processing will handle sentence detection and grammar correction
class SpeakerEngine {
  final IPermissionService _permission;
  final ISpeechToTextService _stt;
  final ISessionService _session;
  final ISocketService _socket;
  final IConnectivityService _connectivity;
  final HermesLogger _log;

  // Core state
  HermesSessionState _state = HermesSessionState.initial();
  StreamController<HermesSessionState>? _stateController;
  Stream<HermesSessionState> get stream =>
      _stateController?.stream ?? const Stream.empty();

  // Session management
  bool _isSessionActive = false;

  // Audience tracking
  int _audienceCount = 0;
  Map<String, int> _languageDistribution = {};

  // Socket subscription
  StreamSubscription<SocketEvent>? _socketSubscription;

  // Infrastructure
  late final StartSessionUseCase _startUseCase;
  late final ConnectivityHandlerUseCase _connHandler;

  SpeakerEngine({
    required IPermissionService permission,
    required ISpeechToTextService stt,
    required ITranslationService translator,
    required ITextToSpeechService tts,
    required ISessionService session,
    required ISocketService socket,
    required IConnectivityService connectivity,
    required ILoggerService logger,
  }) : _permission = permission,
       _stt = stt,
       _session = session,
       _socket = socket,
       _connectivity = connectivity,
       _log = HermesLogger(logger) {
    _ensureStateController();

    _startUseCase = StartSessionUseCase(
      permissionService: _permission,
      sttService: _stt,
      sessionService: _session,
      socketService: _socket,
      logger: _log,
    );
    _connHandler = ConnectivityHandlerUseCase(
      connectivityService: _connectivity,
      logger: _log,
    );
  }

  void _ensureStateController() {
    if (_stateController == null || _stateController!.isClosed) {
      _stateController?.close();
      _stateController = StreamController<HermesSessionState>.broadcast();
      print('🔄 [SpeakerEngine] Created new state controller');
    }
  }

  /// Starts speaker flow with simplified continuous listening
  Future<void> start({required String languageCode}) async {
    print('🎤 [SpeakerEngine] Starting simplified speaker session...');

    try {
      _ensureStateController();
      _emit(_state.copyWith(status: HermesStatus.buffering));

      await _startUseCase.execute(isSpeaker: true, languageCode: languageCode);
      _listenToSocketEvents();
      _connHandler.startMonitoring(
        onOffline: _handleOffline,
        onOnline: _handleOnline,
      );

      _isSessionActive = true;
      _startListening();
    } catch (e, stackTrace) {
      print('❌ [SpeakerEngine] Failed to start session: $e');
      _log.error(
        'Speaker session start failed',
        error: e,
        stackTrace: stackTrace,
      );
      _emit(
        _state.copyWith(
          status: HermesStatus.error,
          errorMessage: 'Failed to start session: $e',
        ),
      );
    }
  }

  void _listenToSocketEvents() {
    _socketSubscription?.cancel();
    _socketSubscription = _socket.onEvent.listen((event) {
      if (event is AudienceUpdateEvent) {
        _handleAudienceUpdate(event);
      } else if (event is SessionJoinEvent) {
        print(
          '👥 [SpeakerEngine] User joined: ${event.userId} (${event.language})',
        );
      } else if (event is SessionLeaveEvent) {
        print('👋 [SpeakerEngine] User left: ${event.userId}');
      }
    });
  }

  void _handleAudienceUpdate(AudienceUpdateEvent event) {
    print(
      '👥 [SpeakerEngine] Audience update: ${event.totalListeners} listeners',
    );
    print('   Languages: ${event.languageDistribution}');

    _audienceCount = event.totalListeners;
    _languageDistribution = event.languageDistribution;

    _emit(
      _state.copyWith(
        audienceCount: _audienceCount,
        languageDistribution: _languageDistribution,
      ),
    );
  }

  void _startListening() {
    if (!_isSessionActive) return;

    print('🎤 [SpeakerEngine] Starting simplified continuous listening...');
    _emit(_state.copyWith(status: HermesStatus.listening));

    // SIMPLIFIED: Only use basic startListening - no pattern detection
    _stt.startListening(
      onResult: _handleSpeechResult,
      onError: _handleSpeechError,
    );
  }

  /// Handle all speech results (all are partials now)
  void _handleSpeechResult(SpeechResult result) async {
    if (!_isSessionActive) {
      print('🚫 [SpeakerEngine] Ignoring speech result - session inactive');
      return;
    }

    print('📝 [SpeakerEngine] Speech result: "${result.transcript}"');

    // Always update UI with latest transcript for real-time feedback
    _emit(
      _state.copyWith(
        status: HermesStatus.listening,
        lastTranscript: result.transcript,
      ),
    );

    // TODO: Buffer-based processing will handle sentence detection
    // For now, just update UI - no transmission to audience
  }

  void _handleSpeechError(Exception error) {
    print('⚠️ [SpeakerEngine] Speech error: $error');

    if (!_isSessionActive) {
      print('🚫 [SpeakerEngine] Ignoring speech error - session inactive');
      return;
    }

    _emit(_state.copyWith(status: HermesStatus.listening, errorMessage: null));
  }

  void _handleOffline() {
    print('📵 [SpeakerEngine] Going offline - pausing session');
    _emit(_state.copyWith(status: HermesStatus.paused));
  }

  void _handleOnline() {
    print('📶 [SpeakerEngine] Coming online - resuming session');
    if (_isSessionActive) {
      _startListening();
    }
  }

  /// Enhanced stop method with proper cleanup
  Future<void> stop() async {
    print('🛑 [SpeakerEngine] Stopping speaker session...');

    _isSessionActive = false;

    try {
      await _stt.stopListening();
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      print('⚠️ [SpeakerEngine] Error stopping STT: $e');
    }

    _socketSubscription?.cancel();
    _socketSubscription = null;
    _connHandler.dispose();

    try {
      await _socket.disconnect();
    } catch (e) {
      print('⚠️ [SpeakerEngine] Error disconnecting socket: $e');
    }

    _audienceCount = 0;
    _languageDistribution = {};

    _emit(_state.copyWith(status: HermesStatus.idle));
    await Future.delayed(const Duration(milliseconds: 50));
    print('✅ [SpeakerEngine] Speaker session stopped');
  }

  Future<void> pause() async {
    print('⏸️ [SpeakerEngine] Pausing session...');
    await _stt.stopListening();
    _emit(_state.copyWith(status: HermesStatus.paused));
  }

  Future<void> resume() async {
    print('▶️ [SpeakerEngine] Resuming session...');
    if (_isSessionActive) {
      _startListening();
    }
  }

  int get audienceCount => _audienceCount;
  Map<String, int> get languageDistribution =>
      Map.unmodifiable(_languageDistribution);

  void _emit(HermesSessionState s) {
    if (_stateController != null && !_stateController!.isClosed) {
      _state = s;
      _stateController!.add(s);
      print('🔄 [SpeakerEngine] State: ${s.status}');
    } else {
      print('⚠️ [SpeakerEngine] Cannot emit state - controller closed or null');
    }
  }

  void dispose() {
    print('🗑️ [SpeakerEngine] Disposing speaker engine...');

    _isSessionActive = false;
    _stt.dispose();
    _socketSubscription?.cancel();
    _connHandler.dispose();

    if (_stateController != null && !_stateController!.isClosed) {
      _stateController!.close();
    }
    _stateController = null;

    print('✅ [SpeakerEngine] Speaker engine disposed');
  }
}
