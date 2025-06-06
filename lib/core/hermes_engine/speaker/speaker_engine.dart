// lib/core/hermes_engine/speaker/speaker_engine.dart
// COMPLETE: Implements 15-second timer + grammar + translation pipeline

import 'dart:async';

import 'package:hermes/core/services/logger/logger_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';
import 'package:hermes/core/services/grammar/language_tool_service.dart';

import '../state/hermes_session_state.dart';
import '../state/hermes_status.dart';
import '../usecases/start_session.dart';
import '../usecases/connectivity_handler.dart';
import '../buffer/sentence_buffer.dart';
import '../buffer/buffer_analytics.dart';
import '../utils/log.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service.dart';
import 'package:hermes/core/services/speech_to_text/speech_result.dart';
import 'package:hermes/core/services/translation/translation_service.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/permission/permission_service.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';

/// Complete SpeakerEngine with 15-second buffering and processing pipeline
class SpeakerEngine {
  final IPermissionService _permission;
  final ISpeechToTextService _stt;
  final ITranslationService _translation;
  final ISessionService _session;
  final ISocketService _socket;
  final IConnectivityService _connectivity;
  final HermesLogger _log;

  // 🆕 NEW: Processing services
  final LanguageToolService _grammar;
  final SentenceBuffer _sentenceBuffer;
  final BufferAnalytics _analytics;

  // Core state
  HermesSessionState _state = HermesSessionState.initial();
  StreamController<HermesSessionState>? _stateController;
  Stream<HermesSessionState> get stream =>
      _stateController?.stream ?? const Stream.empty();

  // Session management
  bool _isSessionActive = false;
  String _targetLanguageCode = '';

  // 🆕 NEW: 15-second processing timer
  Timer? _processingTimer;
  static const Duration _processingInterval = Duration(seconds: 15);

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
    required LanguageToolService grammar, // 🆕 NEW
    required SentenceBuffer sentenceBuffer, // 🆕 NEW
    required BufferAnalytics analytics, // 🆕 NEW
  }) : _permission = permission,
       _stt = stt,
       _translation = translator,
       _session = session,
       _socket = socket,
       _connectivity = connectivity,
       _log = HermesLogger(logger),
       _grammar = grammar, // 🆕 NEW
       _sentenceBuffer = sentenceBuffer, // 🆕 NEW
       _analytics = analytics {
    // 🆕 NEW
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

  /// Starts speaker flow with complete processing pipeline
  Future<void> start({required String languageCode}) async {
    print('🎤 [SpeakerEngine] Starting COMPLETE speaker session...');

    try {
      _ensureStateController();
      _targetLanguageCode = languageCode;
      _emit(_state.copyWith(status: HermesStatus.buffering));

      // Initialize services
      await _initializeProcessingServices();

      await _startUseCase.execute(isSpeaker: true, languageCode: languageCode);
      _listenToSocketEvents();
      _connHandler.startMonitoring(
        onOffline: _handleOffline,
        onOnline: _handleOnline,
      );

      _isSessionActive = true;
      _startProcessingPipeline(); // 🆕 NEW
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

  /// 🆕 NEW: Initialize grammar and analytics services
  Future<void> _initializeProcessingServices() async {
    print('🔧 [SpeakerEngine] Initializing processing services...');

    // Initialize grammar service
    final grammarInitialized = await _grammar.initialize();
    if (!grammarInitialized) {
      print(
        '⚠️ [SpeakerEngine] Grammar service failed to initialize - continuing without grammar correction',
      );
    }

    // Start analytics session
    _analytics.startSession();

    print('✅ [SpeakerEngine] Processing services initialized');
  }

  /// 🆕 NEW: Start the 15-second processing pipeline
  void _startProcessingPipeline() {
    print('⏰ [SpeakerEngine] Starting 15-second processing timer...');

    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(_processingInterval, (_) {
      _processAccumulatedText('timer');
    });

    // Also check for force flush every 5 seconds
    Timer.periodic(const Duration(seconds: 5), (_) {
      if (!_isSessionActive) return;
      if (_sentenceBuffer.shouldForceFlush()) {
        _processAccumulatedText('force');
      }
    });
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

    print('🎤 [SpeakerEngine] Starting continuous listening...');
    _emit(_state.copyWith(status: HermesStatus.listening));

    _stt.startListening(
      onResult: _handleSpeechResult,
      onError: _handleSpeechError,
    );
  }

  /// Handle continuous partial speech results
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

    // 🆕 NEW: Check for complete sentences and process immediately
    final completeSentences = _sentenceBuffer.getCompleteSentencesForProcessing(
      result.transcript,
    );
    if (completeSentences != null) {
      print(
        '🎯 [SpeakerEngine] Found complete sentences, processing immediately...',
      );
      await _processText(completeSentences, 'punctuation');
    }
  }

  /// 🆕 NEW: Process accumulated text (called by timer or force flush)
  Future<void> _processAccumulatedText(String reason) async {
    if (!_isSessionActive) return;

    final textToProcess = _sentenceBuffer.flushPending(reason: reason);
    if (textToProcess != null) {
      print(
        '⏰ [SpeakerEngine] Processing accumulated text ($reason): "$textToProcess"',
      );
      await _processText(textToProcess, reason);
    }
  }

  /// 🆕 NEW: Complete processing pipeline: grammar → translation → broadcast
  Future<void> _processText(String text, String reason) async {
    if (!_isSessionActive || text.trim().isEmpty) return;

    final processingStart = DateTime.now();
    print(
      '🔄 [SpeakerEngine] Starting processing pipeline for: "${text.substring(0, text.length.clamp(0, 50))}..."',
    );

    try {
      _emit(_state.copyWith(status: HermesStatus.translating));

      // Step 1: Grammar correction
      final grammarStart = DateTime.now();
      final correctedText = await _grammar.correctGrammar(text);
      final grammarLatency = DateTime.now().difference(grammarStart);

      print(
        '📝 [SpeakerEngine] Grammar correction took ${grammarLatency.inMilliseconds}ms',
      );
      if (correctedText != text) {
        print('✏️ [SpeakerEngine] Grammar corrections applied');
        print(
          '   Original: "${text.substring(0, text.length.clamp(0, 40))}..."',
        );
        print(
          '   Corrected: "${correctedText.substring(0, correctedText.length.clamp(0, 40))}..."',
        );
      }

      // Step 2: Translation
      final translationStart = DateTime.now();
      final translationResult = await _translation.translate(
        text: correctedText,
        targetLanguageCode: _targetLanguageCode,
      );
      final translationLatency = DateTime.now().difference(translationStart);

      print(
        '🌍 [SpeakerEngine] Translation took ${translationLatency.inMilliseconds}ms',
      );
      print(
        '🌍 [SpeakerEngine] Translated: "${translationResult.translatedText}"',
      );

      // Step 3: Broadcast to audience
      await _broadcastTranslation(translationResult.translatedText);

      // Update analytics
      final endToEndLatency = DateTime.now().difference(processingStart);
      _analytics.logBufferProcessed(
        textLength: text.length,
        sentenceCount: _countSentences(text),
        hadPunctuation: reason == 'punctuation',
        wasForcedSend: reason == 'force',
        grammarLatency: grammarLatency,
        translationLatency: translationLatency,
      );

      print(
        '✅ [SpeakerEngine] Processing complete in ${endToEndLatency.inMilliseconds}ms',
      );

      // Return to listening
      _emit(_state.copyWith(status: HermesStatus.listening));
    } catch (e, stackTrace) {
      print('❌ [SpeakerEngine] Processing failed: $e');
      _log.error('Text processing failed', error: e, stackTrace: stackTrace);

      // Record failure in analytics
      _analytics.logBufferProcessed(
        textLength: text.length,
        sentenceCount: _countSentences(text),
        hadPunctuation: reason == 'punctuation',
        wasForcedSend: reason == 'force',
        grammarLatency: Duration.zero,
        translationLatency: Duration.zero,
        grammarFailed: true,
        translationFailed: true,
      );

      // Return to listening despite error
      _emit(_state.copyWith(status: HermesStatus.listening));
    }
  }

  /// 🆕 NEW: Broadcast translation to all audience members
  Future<void> _broadcastTranslation(String translatedText) async {
    try {
      final sessionId = _session.currentSession?.sessionId;
      if (sessionId == null) {
        print('❌ [SpeakerEngine] Cannot broadcast - no session ID');
        return;
      }

      final event = TranslationEvent(
        sessionId: sessionId,
        translatedText: translatedText,
        targetLanguage: _targetLanguageCode,
      );

      await _socket.send(event);
      print(
        '📡 [SpeakerEngine] Translation broadcasted to $_audienceCount listeners',
      );

      // Update UI with last translation
      _emit(_state.copyWith(lastTranslation: translatedText));
    } catch (e) {
      print('❌ [SpeakerEngine] Failed to broadcast translation: $e');
      throw Exception('Failed to broadcast translation: $e');
    }
  }

  /// Helper to count sentences in text
  int _countSentences(String text) {
    return text
        .split(RegExp(r'[.!?]+'))
        .where((s) => s.trim().isNotEmpty)
        .length;
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

    // Stop processing timer
    _processingTimer?.cancel();
    _processingTimer = null;

    // Process any remaining text before stopping
    await _processAccumulatedText('stop');

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

    // Clear buffers
    _sentenceBuffer.clear();
    _audienceCount = 0;
    _languageDistribution = {};

    _emit(_state.copyWith(status: HermesStatus.idle));
    await Future.delayed(const Duration(milliseconds: 50));
    print('✅ [SpeakerEngine] Speaker session stopped');
  }

  Future<void> pause() async {
    print('⏸️ [SpeakerEngine] Pausing session...');
    _processingTimer?.cancel();
    await _stt.stopListening();
    _emit(_state.copyWith(status: HermesStatus.paused));
  }

  Future<void> resume() async {
    print('▶️ [SpeakerEngine] Resuming session...');
    if (_isSessionActive) {
      _startProcessingPipeline();
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
    _processingTimer?.cancel();
    _stt.dispose();
    _socketSubscription?.cancel();
    _connHandler.dispose();
    _grammar.dispose();

    if (_stateController != null && !_stateController!.isClosed) {
      _stateController!.close();
    }
    _stateController = null;

    print('✅ [SpeakerEngine] Speaker engine disposed');
  }
}
