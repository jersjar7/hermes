import 'dart:async';
import 'dart:math';

import 'package:hermes/core/services/connectivity/connectivity_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service.dart';
import 'package:hermes/core/services/translation/translation_service.dart';

import 'session_info.dart';
import 'session_service.dart';

class SessionServiceImpl implements ISessionService {
  final ISocketService _socketService;
  final ISpeechToTextService _sttService;
  final ITranslationService _translationService;
  final ITextToSpeechService _ttsService;
  final IConnectivityService _connectivityService;

  StreamSubscription<bool>? _connectivitySub;

  SessionServiceImpl({
    required ISocketService socketService,
    required ISpeechToTextService sttService,
    required ITranslationService translationService,
    required ITextToSpeechService ttsService,
    required IConnectivityService connectivityService,
  }) : _socketService = socketService,
       _sttService = sttService,
       _translationService = translationService,
       _ttsService = ttsService,
       _connectivityService = connectivityService;

  SessionInfo? _session;
  bool _isSpeaker = false;

  @override
  bool get isSpeaker => _isSpeaker;

  @override
  bool get isSessionActive => _session != null;

  @override
  bool get isSessionPaused => _session?.isPaused ?? false;

  @override
  SessionInfo? get currentSession => _session;

  @override
  Future<void> startSession({required String languageCode}) async {
    final sessionId = _generateSessionCode();
    _session = SessionInfo(
      sessionId: sessionId,
      languageCode: languageCode,
      startedAt: DateTime.now(),
    );
    _isSpeaker = true;

    await _socketService.connect(sessionId);

    final ok = await _sttService.initialize();
    if (ok) {
      await _sttService.startListening(
        onResult: (result) async {
          print('🎙️ Transcribed: ${result.transcript}');

          final translated = await _translationService.translate(
            text: result.transcript,
            targetLanguageCode: _session!.languageCode,
          );

          print('🌍 Translated: ${translated.translatedText}');

          await _socketService.send(
            TranslationEvent(
              sessionId: _session!.sessionId,
              translatedText: translated.translatedText,
              targetLanguage: translated.targetLanguageCode,
            ),
          );
        },
        onError: (e) => print('❌ STT error: $e'),
      );
    }
    // Monitor connectivity
    _connectivitySub = _connectivityService.onStatusChange.listen((
      isOnline,
    ) async {
      if (!_isSpeaker) return; // Only react if speaker

      if (!isOnline) {
        print('🔌 Connection lost. Pausing session...');
        await pauseSession();
      } else if (_session?.isPaused == true) {
        print('🔌 Connection restored. Resuming session...');
        await resumeSession();
      }
    });
  }

  @override
  Future<void> endSession() async {
    await _sttService.cancel();
    await _socketService.disconnect();
    _connectivitySub?.cancel();

    _session = null;
    _isSpeaker = false;
  }

  @override
  Future<void> pauseSession() async {
    await _sttService.stopListening();
    if (_session != null) {
      _session = _session!.copyWith(isPaused: true);
    }
  }

  @override
  Future<void> resumeSession() async {
    if (_session != null) {
      _session = _session!.copyWith(isPaused: false);
    }

    await _sttService.startListening(
      onResult: (result) async {
        print('🎙️ (Resume) Transcribed: ${result.transcript}');

        final translated = await _translationService.translate(
          text: result.transcript,
          targetLanguageCode: _session!.languageCode,
        );

        print('🌍 Translated: ${translated.translatedText}');

        await _socketService.send(
          TranslationEvent(
            sessionId: _session!.sessionId,
            translatedText: translated.translatedText,
            targetLanguage: translated.targetLanguageCode,
          ),
        );
      },
      onError: (e) => print('❌ STT error: $e'),
    );
  }

  @override
  Future<void> joinSession(String sessionCode) async {
    _session = SessionInfo(
      sessionId: sessionCode,
      languageCode: 'en-US',
      startedAt: DateTime.now(),
    );
    _isSpeaker = false;

    await _ttsService.initialize();
    await _socketService.connect(sessionCode);

    _socketService.onEvent.listen((event) async {
      if (event is TranslationEvent) {
        print('🎧 Received Translation: ${event.translatedText}');
        await _ttsService.speak(event.translatedText);
      }
    });
  }

  @override
  Future<void> leaveSession() async {
    await _socketService.disconnect();
    _connectivitySub?.cancel();

    _session = null;
    _isSpeaker = false;
  }

  String _generateSessionCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rand = Random();
    return List.generate(6, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
