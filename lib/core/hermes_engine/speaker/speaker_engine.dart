// lib/core/hermes_engine/speaker/speaker_engine.dart

import 'dart:async';

import 'package:hermes/core/services/logger/logger_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';

import '../buffer/translation_buffer.dart';
import '../config/hermes_config.dart';
import '../state/hermes_session_state.dart';
import '../state/hermes_status.dart';
import '../usecases/start_session.dart';
import '../usecases/process_transcript.dart';
import '../usecases/buffer_management.dart';
import '../usecases/connectivity_handler.dart';
import '../utils/log.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service.dart';
import 'package:hermes/core/services/translation/translation_service.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/permission/permission_service.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';

/// Orchestrates speaker-side flow: listen, translate, buffer, playback, connectivity.
class SpeakerEngine {
  final IPermissionService _permission;
  final ISpeechToTextService _stt;
  final ITranslationService _translator;
  final ISessionService _session;
  final ISocketService _socket;
  final IConnectivityService _connectivity;
  final HermesLogger _log;

  // Core state
  HermesSessionState _state = HermesSessionState.initial();
  final _stateController = StreamController<HermesSessionState>.broadcast();
  Stream<HermesSessionState> get stream => _stateController.stream;

  // Session management
  bool _isSessionActive = false;
  String? _currentLanguageCode;

  // Audience tracking
  int _audienceCount = 0;
  Map<String, int> _languageDistribution = {};

  // Socket subscription
  StreamSubscription<SocketEvent>? _socketSubscription;

  // Infrastructure
  late final StartSessionUseCase _startUseCase;
  late final ProcessTranscriptUseCase _processUseCase;
  late final BufferManagementUseCase _bufferMgr;
  late final ConnectivityHandlerUseCase _connHandler;
  final TranslationBuffer _buffer = TranslationBuffer();

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
       _translator = translator,
       _session = session,
       _socket = socket,
       _connectivity = connectivity,
       _log = HermesLogger(logger) {
    _startUseCase = StartSessionUseCase(
      permissionService: _permission,
      sttService: _stt,
      sessionService: _session,
      socketService: _socket,
      logger: _log,
    );
    _processUseCase = ProcessTranscriptUseCase(
      translator: _translator,
      buffer: _buffer,
      logger: _log,
    );
    _bufferMgr = BufferManagementUseCase(buffer: _buffer, logger: _log);
    _connHandler = ConnectivityHandlerUseCase(
      connectivityService: _connectivity,
      logger: _log,
    );
  }

  /// Starts speaker flow: session setup, STT listening, translation, socket.
  Future<void> start({required String languageCode}) async {
    print('🎤 [SpeakerEngine] Starting speaker session...');
    _currentLanguageCode = languageCode;

    try {
      // Set initial state
      _emit(_state.copyWith(status: HermesStatus.buffering));

      // Initialize session
      await _startUseCase.execute(isSpeaker: true, languageCode: languageCode);

      // Start listening to socket events
      _listenToSocketEvents();

      // Start connectivity monitoring
      _connHandler.startMonitoring(
        onOffline: _handleOffline,
        onOnline: _handleOnline,
      );

      // Session is now active
      _isSessionActive = true;

      // Start listening immediately
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
      // We don't handle TranslationEvent here - speakers don't see translations
    });
  }

  void _handleAudienceUpdate(AudienceUpdateEvent event) {
    print(
      '👥 [SpeakerEngine] Audience update: ${event.totalListeners} listeners',
    );
    print('   Languages: ${event.languageDistribution}');

    _audienceCount = event.totalListeners;
    _languageDistribution = event.languageDistribution;

    // Update state with audience info
    _emit(
      _state.copyWith(
        audienceCount: _audienceCount,
        languageDistribution: _languageDistribution,
      ),
    );
  }

  void _startListening() {
    if (!_isSessionActive) return;

    print('🎤 [SpeakerEngine] Starting continuous listening...');
    _emit(_state.copyWith(status: HermesStatus.listening));

    _stt.startListening(
      onResult: _handleSpeechResult,
      onError: _handleSpeechError,
    );
  }

  void _handleSpeechResult(res) async {
    if (!_isSessionActive) return;

    print(
      '📝 [SpeakerEngine] Speech result: "${res.transcript}" (final: ${res.isFinal})',
    );

    // Always update UI with latest transcript for real-time feedback
    _emit(
      _state.copyWith(
        status: res.isFinal ? HermesStatus.translating : HermesStatus.listening,
        lastTranscript: res.transcript,
      ),
    );

    // Only process final results for translation
    if (!res.isFinal) return;

    print('🔄 [SpeakerEngine] Processing final transcript for translation');

    try {
      // Note: For speaker UI, we don't translate their own speech
      // We just send the transcript to connected audience members
      // who will receive translations in their selected languages

      // Send the original transcript over socket
      _socket.send(
        TranscriptEvent(
          sessionId: _session.currentSession!.sessionId,
          text: res.transcript,
          isFinal: true,
        ),
      );

      print('✅ [SpeakerEngine] Transcript sent to audience');

      // Continue listening
      _emit(
        _state.copyWith(
          status: HermesStatus.listening,
          // Note: We don't set lastTranslation for speakers
        ),
      );
    } catch (e, stackTrace) {
      print('❌ [SpeakerEngine] Failed to send transcript: $e');
      _log.error('Failed to send transcript', error: e, stackTrace: stackTrace);

      // Don't stop the session on errors, just continue listening
      _emit(
        _state.copyWith(
          status: HermesStatus.listening,
          errorMessage: 'Failed to send transcript: $e',
        ),
      );
    }
  }

  void _handleSpeechError(Exception error) {
    print('⚠️ [SpeakerEngine] Speech error: $error');

    // For non-critical errors, just continue listening
    // The STT service should handle auto-recovery
    if (!_isSessionActive) return;

    // Update UI but keep session active
    _emit(
      _state.copyWith(
        status: HermesStatus.listening, // Keep showing as listening
        errorMessage: null, // Clear any previous errors
      ),
    );
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

  /// Stops the speaker session
  Future<void> stop() async {
    print('🛑 [SpeakerEngine] Stopping speaker session...');

    _isSessionActive = false;
    _currentLanguageCode = null;

    // Stop listening
    await _stt.stopListening();

    // Cancel socket subscription
    _socketSubscription?.cancel();

    // Stop connectivity monitoring
    _connHandler.dispose();

    // Disconnect socket
    await _socket.disconnect();

    // Reset audience tracking
    _audienceCount = 0;
    _languageDistribution = {};

    // Update state
    _emit(_state.copyWith(status: HermesStatus.idle));

    print('✅ [SpeakerEngine] Speaker session stopped');
  }

  /// Pauses the session (stops listening but keeps session active)
  Future<void> pause() async {
    print('⏸️ [SpeakerEngine] Pausing session...');
    await _stt.stopListening();
    _emit(_state.copyWith(status: HermesStatus.paused));
  }

  /// Resumes the session (starts listening again)
  Future<void> resume() async {
    print('▶️ [SpeakerEngine] Resuming session...');
    if (_isSessionActive) {
      _startListening();
    }
  }

  void _emit(HermesSessionState s) {
    _state = s;
    _stateController.add(s);
    print('🔄 [SpeakerEngine] State: ${s.status}');
  }

  void dispose() {
    _isSessionActive = false;
    _stt.dispose();
    _socketSubscription?.cancel();
    _connHandler.dispose();
    _stateController.close();
  }
}
