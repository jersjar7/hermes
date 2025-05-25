import 'dart:async';

import 'package:hermes/core/services/connectivity/connectivity_service.dart';
import 'package:hermes/core/services/logger/logger_service.dart';
import 'package:hermes/core/services/permission/permission_service.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service.dart';
import 'package:hermes/core/services/translation/translation_service.dart';

import 'buffer/countdown_timer.dart';
import 'buffer/translation_buffer.dart';
import 'hermes_config.dart';
import 'state/hermes_session_state.dart';
import 'state/hermes_status.dart';
import 'utils/log.dart';

class HermesEngine {
  // === Services ===
  final ISpeechToTextService _stt;
  final ITranslationService _translator;
  final ITextToSpeechService _tts;
  final ISocketService _socket;
  final ISessionService _session;
  final ILoggerService _logger;
  final IPermissionService _permission;
  final IConnectivityService _connectivity;

  // === Logging Helper ===
  late final HermesLogger _log;

  // === State ===
  final _stateController = StreamController<HermesSessionState>.broadcast();
  HermesSessionState _state = HermesSessionState.initial();
  Stream<HermesSessionState> get stateStream => _stateController.stream;
  HermesSessionState get currentState => _state;

  final _buffer = TranslationBuffer();
  final _countdown = CountdownTimer();

  bool _isRunning = false;
  bool _isSpeaker = false;
  String _targetLang = 'en';

  StreamSubscription<bool>? _connectivitySub;

  HermesEngine({
    required ISpeechToTextService stt,
    required ITranslationService translator,
    required ITextToSpeechService tts,
    required ISocketService socket,
    required ISessionService session,
    required ILoggerService logger,
    required IPermissionService permission,
    required IConnectivityService connectivity,
  }) : _stt = stt,
       _translator = translator,
       _tts = tts,
       _socket = socket,
       _session = session,
       _logger = logger,
       _permission = permission,
       _connectivity = connectivity {
    _log = HermesLogger(_logger);
  }

  // === Session Control ===

  Future<void> startSession(String lang) async {
    if (_isRunning) return;
    _targetLang = lang;
    _isRunning = true;
    _isSpeaker = _session.isSpeaker;
    _log.info(
      'Starting session as ${_isSpeaker ? 'speaker' : 'audience'}',
      tag: 'Lifecycle',
    );

    if (_isSpeaker) {
      final granted = await _permission.requestMicrophonePermission();
      if (!granted) return _fail('Mic permission denied.');

      if (!await _stt.initialize()) return _fail('STT init failed.');
      await _session.startSession(languageCode: _targetLang);
      await _socket.connect(_session.currentSession!.sessionId);
      _handleConnectivity();
      _listenToSpeech();
    } else {
      await _session.joinSession(_session.currentSession!.sessionId);
      await _socket.connect(_session.currentSession!.sessionId);
      _handleSocketForAudience();
    }

    _emit(_state.copyWith(status: HermesStatus.buffering));
  }

  Future<void> stopSession() async {
    _log.info('Stopping session', tag: 'Lifecycle');
    _isRunning = false;
    _buffer.clear();
    _countdown.stop();
    _connectivitySub?.cancel();
    await _tts.stop();
    await _stt.stopListening();
    await _socket.disconnect();
    await _session.endSession();
    _emit(HermesSessionState.initial());
  }

  // === Core Handlers ===

  void _listenToSpeech() async {
    await _stt.startListening(
      onResult: (res) async {
        if (!_isRunning || !res.isFinal || res.transcript.trim().isEmpty) {
          return;
        }

        _emit(
          _state.copyWith(
            lastTranscript: res.transcript,
            status: HermesStatus.translating,
          ),
        );

        try {
          final result = await _translator.translate(
            text: res.transcript,
            targetLanguageCode: _targetLang,
          );
          _buffer.add(result.translatedText);
          _emit(
            _state.copyWith(
              lastTranslation: result.translatedText,
              buffer: _buffer.all,
            ),
          );
          _socket.send(
            TranslationEvent(
              sessionId: _session.currentSession!.sessionId,
              translatedText: result.translatedText,
              targetLanguage: _targetLang,
            ),
          );

          if (_buffer.length == kMinBufferBeforeSpeaking) {
            _startCountdown();
          }
        } catch (e, stack) {
          _log.error(
            'Translation failed',
            error: e,
            stackTrace: stack,
            tag: 'Translation',
          );
          _emit(
            _state.copyWith(
              status: HermesStatus.error,
              errorMessage: 'Translation failed.',
            ),
          );
        }
      },
      onError: (e) => _fail('STT Error: ${e.toString()}'),
    );
  }

  void _speakNext() async {
    if (!_isRunning || _buffer.isEmpty) {
      return _emit(_state.copyWith(status: HermesStatus.paused));
    }

    final text = _buffer.pop();
    if (text == null) return;
    _emit(_state.copyWith(status: HermesStatus.speaking, buffer: _buffer.all));

    try {
      await _tts.speak(text);
      _emit(_state.copyWith(buffer: _buffer.all));
      _speakNext(); // recursively speak next
    } catch (e, stack) {
      _log.error('TTS failed', error: e, stackTrace: stack, tag: 'TTS');
      _emit(
        _state.copyWith(
          status: HermesStatus.error,
          errorMessage: 'TTS failed.',
        ),
      );
    }
  }

  void _startCountdown() {
    _emit(
      _state.copyWith(
        status: HermesStatus.countdown,
        countdownSeconds: kInitialCountdownSeconds,
      ),
    );
    _countdown.onTick =
        (sec) => _emit(
          _state.copyWith(
            status: HermesStatus.countdown,
            countdownSeconds: sec,
          ),
        );
    _countdown.onComplete = _speakNext;
    _countdown.start(kInitialCountdownSeconds);
    _log.info(
      'Countdown started for $kInitialCountdownSeconds seconds',
      tag: 'Countdown',
    );
  }

  void _handleConnectivity() {
    _connectivitySub = _connectivity.onStatusChange.listen((isOnline) {
      if (!isOnline) {
        _log.info('Lost connection – pausing STT', tag: 'Connectivity');
        _pauseSession('Offline');
      } else if (_isRunning && _session.isSessionPaused) {
        _log.info('Back online – resuming STT', tag: 'Connectivity');
        _resumeSession();
      }
    });
  }

  void _pauseSession(String reason) async {
    await _session.pauseSession();
    await _stt.stopListening();
    await _tts.stop();
    _emit(_state.copyWith(status: HermesStatus.paused, errorMessage: reason));
    _log.info('Session paused: $reason', tag: 'Lifecycle');
  }

  void _resumeSession() async {
    await _session.resumeSession();
    _listenToSpeech();
    _emit(_state.copyWith(status: HermesStatus.buffering, errorMessage: null));
    _log.info('Session resumed', tag: 'Lifecycle');
  }

  void _handleSocketForAudience() {
    _socket.onEvent.listen((event) async {
      if (event is TranslationEvent) {
        _buffer.add(event.translatedText);
        _emit(_state.copyWith(buffer: _buffer.all));
        _log.info(
          'Received translation: ${event.translatedText}',
          tag: 'Socket',
        );

        if (_state.status != HermesStatus.speaking &&
            _buffer.length >= kMinBufferBeforeSpeaking) {
          _startCountdown();
        }
      }
    });
  }

  // === Utilities ===

  void _emit(HermesSessionState state) {
    _state = state;
    _stateController.add(state);
  }

  void _fail(String message) {
    _log.error('Fatal engine error: $message', tag: 'Failure');
    _emit(_state.copyWith(status: HermesStatus.error, errorMessage: message));
    stopSession();
  }
}
