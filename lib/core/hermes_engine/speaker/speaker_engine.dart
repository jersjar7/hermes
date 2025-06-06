// lib/core/hermes_engine/speaker/speaker_engine.dart
// INTEGRATED: 15-second buffer processing with grammar correction

import 'dart:async';

import 'package:hermes/core/services/logger/logger_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';
import 'package:hermes/core/services/grammar/language_tool_service.dart';

import '../state/hermes_session_state.dart';
import '../state/hermes_status.dart';
import '../usecases/start_session.dart';
import '../usecases/connectivity_handler.dart';
import '../utils/log.dart';
import '../buffer/sentence_buffer.dart';
import '../buffer/buffer_analytics.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service.dart';
import 'package:hermes/core/services/speech_to_text/speech_result.dart';
import 'package:hermes/core/services/translation/translation_service.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/permission/permission_service.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';

/// SpeakerEngine with 15-second buffer processing and grammar correction
class SpeakerEngine {
  final IPermissionService _permission;
  final ISpeechToTextService _stt;
  final ITranslationService _translator;
  final ISessionService _session;
  final ISocketService _socket;
  final IConnectivityService _connectivity;
  final HermesLogger _log;

  // Buffer processing services
  final SentenceBuffer _buffer = SentenceBuffer();
  final LanguageToolService _grammar = LanguageToolService();
  final BufferAnalytics _analytics = BufferAnalytics();

  // Core state
  HermesSessionState _state = HermesSessionState.initial();
  StreamController<HermesSessionState>? _stateController;
  Stream<HermesSessionState> get stream =>
      _stateController?.stream ?? const Stream.empty();

  // Session management
  bool _isSessionActive = false;
  String _currentLanguageCode = 'en-US';

  // Buffer processing
  Timer? _bufferTimer;
  bool _isProcessing = false;

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
       _translator = translator,
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

  /// Starts speaker flow with buffer-based processing
  Future<void> start({required String languageCode}) async {
    print('🎤 [SpeakerEngine] Starting buffer-based speaker session...');
    _currentLanguageCode = languageCode;

    try {
      _ensureStateController();
      _emit(_state.copyWith(status: HermesStatus.buffering));

      // Initialize grammar service
      await _grammar.initialize();
      _analytics.startSession();

      await _startUseCase.execute(isSpeaker: true, languageCode: languageCode);
      _listenToSocketEvents();
      _connHandler.startMonitoring(
        onOffline: _handleOffline,
        onOnline: _handleOnline,
      );

      _isSessionActive = true;
      _startListening();
      _startBufferTimer();
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

    print('🎤 [SpeakerEngine] Starting continuous listening for buffer...');
    _emit(_state.copyWith(status: HermesStatus.listening));

    _stt.startListening(
      onResult: _handleSpeechResult,
      onError: _handleSpeechError,
    );
  }

  /// Start 15-second buffer processing timer
  void _startBufferTimer() {
    _bufferTimer?.cancel();
    _bufferTimer = Timer.periodic(const Duration(seconds: 15), (_) async {
      await _processBuffer(reason: 'timer');
    });
    print('⏱️ [SpeakerEngine] Started 15-second buffer timer');
  }

  /// Handle speech results by feeding to buffer
  void _handleSpeechResult(SpeechResult result) async {
    if (!_isSessionActive) return;

    // Always update UI with latest transcript
    _emit(
      _state.copyWith(
        status: HermesStatus.listening,
        lastTranscript: result.transcript,
      ),
    );

    // Check for complete sentences in buffer
    final completeSentences = _buffer.getCompleteSentencesForProcessing(
      result.transcript,
    );
    if (completeSentences != null) {
      print(
        '📝 [SpeakerEngine] Buffer found complete sentences, processing immediately',
      );
      await _processText(completeSentences, reason: 'punctuation');
    }

    // Check if we should force flush (30-second rule)
    if (_buffer.shouldForceFlush()) {
      print('⏰ [SpeakerEngine] Force flush triggered');
      await _processBuffer(reason: 'force');
    }
  }

  /// Process buffer content (called by timer or force flush)
  Future<void> _processBuffer({required String reason}) async {
    final textToProcess = _buffer.flushPending(reason: reason);
    if (textToProcess != null) {
      await _processText(textToProcess, reason: reason);
    }
  }

  /// Core processing pipeline: Grammar correction → Translation → Send
  Future<void> _processText(String text, {required String reason}) async {
    if (!_isSessionActive || _isProcessing) return;

    _isProcessing = true;
    _emit(_state.copyWith(status: HermesStatus.translating));

    final startTime = DateTime.now();
    bool grammarFailed = false;
    bool translationFailed = false;

    try {
      print(
        '🔄 [SpeakerEngine] Processing: "${text.substring(0, text.length.clamp(0, 50))}..."',
      );

      // Step 1: Grammar correction with timeout
      final grammarStart = DateTime.now();
      final correctedText = await _grammar.correctGrammar(text);
      final grammarLatency = DateTime.now().difference(grammarStart);

      if (correctedText == text) {
        print('📝 [SpeakerEngine] No grammar corrections applied');
      } else {
        print('✏️ [SpeakerEngine] Applied grammar corrections');
      }

      // Step 2: Translation
      final translationStart = DateTime.now();
      String translatedText;

      try {
        final result = await _translator.translate(
          text: correctedText,
          targetLanguageCode: _currentLanguageCode,
        );
        translatedText = result.translatedText;
      } catch (e) {
        print('❌ [SpeakerEngine] Translation failed: $e, using corrected text');
        translatedText = correctedText;
        translationFailed = true;
      }

      final translationLatency = DateTime.now().difference(translationStart);

      // Step 3: Send to audience
      await _sendToAudience(translatedText);

      // Log analytics
      final sentences = _countSentences(text);
      _analytics.logBufferProcessed(
        textLength: text.length,
        sentenceCount: sentences,
        hadPunctuation: reason == 'punctuation',
        wasForcedSend: reason == 'force',
        grammarLatency: grammarLatency,
        translationLatency: translationLatency,
        grammarFailed: grammarFailed,
        translationFailed: translationFailed,
      );

      final totalLatency = DateTime.now().difference(startTime);
      print(
        '✅ [SpeakerEngine] Processed in ${totalLatency.inMilliseconds}ms (reason: $reason)',
      );
    } catch (e, stackTrace) {
      print('❌ [SpeakerEngine] Processing failed: $e');
      _log.error('Buffer processing failed', error: e, stackTrace: stackTrace);
    } finally {
      _isProcessing = false;
      if (_isSessionActive) {
        _emit(_state.copyWith(status: HermesStatus.listening));
      }
    }
  }

  /// Send processed text to audience via socket
  Future<void> _sendToAudience(String text) async {
    try {
      await _socket.send(
        TranscriptEvent(
          sessionId: _session.currentSession!.sessionId,
          text: text,
          isFinal: true,
        ),
      );
      print(
        '📤 [SpeakerEngine] Sent to audience: "${text.substring(0, text.length.clamp(0, 50))}..."',
      );
    } catch (e) {
      print('❌ [SpeakerEngine] Failed to send to audience: $e');
      rethrow;
    }
  }

  int _countSentences(String text) {
    return RegExp(r'[.!?]+').allMatches(text).length.clamp(1, 99);
  }

  void _handleSpeechError(Exception error) {
    print('⚠️ [SpeakerEngine] Speech error: $error');
    if (_isSessionActive) {
      _emit(
        _state.copyWith(status: HermesStatus.listening, errorMessage: null),
      );
    }
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

  /// Stop session and cleanup
  Future<void> stop() async {
    print('🛑 [SpeakerEngine] Stopping buffer-based session...');
    _isSessionActive = false;

    // Process any remaining buffer content
    await _processBuffer(reason: 'cleanup');

    _bufferTimer?.cancel();
    _bufferTimer = null;

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

    _buffer.clear();
    _grammar.dispose();
    _audienceCount = 0;
    _languageDistribution = {};

    print(
      '📊 [SpeakerEngine] Final analytics: ${_analytics.getDebugSummary()}',
    );

    _emit(_state.copyWith(status: HermesStatus.idle));
    print('✅ [SpeakerEngine] Buffer-based session stopped');
  }

  Future<void> pause() async {
    print('⏸️ [SpeakerEngine] Pausing session...');
    _bufferTimer?.cancel();
    await _stt.stopListening();
    _emit(_state.copyWith(status: HermesStatus.paused));
  }

  Future<void> resume() async {
    print('▶️ [SpeakerEngine] Resuming session...');
    if (_isSessionActive) {
      _startListening();
      _startBufferTimer();
    }
  }

  int get audienceCount => _audienceCount;
  Map<String, int> get languageDistribution =>
      Map.unmodifiable(_languageDistribution);

  /// Get buffer analytics for monitoring
  Map<String, dynamic> getAnalytics() => _analytics.getAnalyticsReport();

  void _emit(HermesSessionState s) {
    if (_stateController != null && !_stateController!.isClosed) {
      _state = s;
      _stateController!.add(s);
    }
  }

  void dispose() {
    print('🗑️ [SpeakerEngine] Disposing buffer-based engine...');
    _isSessionActive = false;
    _bufferTimer?.cancel();
    _stt.dispose();
    _socketSubscription?.cancel();
    _connHandler.dispose();
    _buffer.clear();
    _grammar.dispose();

    if (_stateController != null && !_stateController!.isClosed) {
      _stateController!.close();
    }
    _stateController = null;
    print('✅ [SpeakerEngine] Buffer-based engine disposed');
  }
}
