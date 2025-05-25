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

  /// Starts speaker flow: session start, STT listening, translation, socket.
  Future<void> start({required String languageCode}) async {
    _emit(_state.copyWith(status: HermesStatus.buffering));

    await _startUseCase.execute(isSpeaker: true, languageCode: languageCode);

    // Begin connectivity monitoring
    _connHandler.startMonitoring(
      onOffline: _handleOffline,
      onOnline: _handleOnline,
    );

    // Start listening loop
    _stt.startListening(
      onResult: (res) async {
        if (!res.isFinal) return;
        _emit(
          _state.copyWith(
            status: HermesStatus.translating,
            lastTranscript: res.transcript,
          ),
        );

        // Translate & buffer
        final event = await _processUseCase.execute(
          res.transcript,
          languageCode,
        );
        _emit(
          _state.copyWith(
            lastTranslation: event.translatedText,
            buffer: _buffer.all,
          ),
        );

        // Send over socket
        _socket.send(
          TranslationEvent(
            sessionId: _session.currentSession!.sessionId,
            translatedText: event.translatedText,
            targetLanguage: languageCode,
          ),
        );

        // Check buffer readiness
        final ready = _bufferMgr.checkBufferReady();
        if (ready != null) {
          _emit(
            _state.copyWith(
              status: HermesStatus.countdown,
              countdownSeconds: kInitialBufferCountdownSeconds,
            ),
          );
          // Start countdown externally in root engine
        }
      },
      onError:
          (e) => _emit(
            _state.copyWith(
              status: HermesStatus.error,
              errorMessage: e.toString(),
            ),
          ),
    );
  }

  void _handleOffline() {
    _stt.stopListening();
    _emit(_state.copyWith(status: HermesStatus.paused));
  }

  void _handleOnline() {
    _stt.startListening(onResult: (_) {}, onError: (_) {});
    _emit(_state.copyWith(status: HermesStatus.buffering));
  }

  void _emit(HermesSessionState s) {
    _state = s;
    _stateController.add(s);
  }

  void dispose() {
    _stt.stopListening();
    _connHandler.dispose();
    _stateController.close();
  }
}
