// lib/core/hermes_engine/speaker/speaker_engine_enhanced.dart
// ENHANCED: Implements improved 15-second timer + enhanced processing pipeline

import 'dart:async';

import 'package:hermes/core/services/logger/logger_service.dart';
import 'package:hermes/core/services/socket/socket_event.dart';
import 'package:hermes/core/services/grammar/language_tool_service.dart';

import '../state/hermes_session_state.dart';
import '../state/hermes_status.dart';
import '../usecases/start_session.dart';
import '../usecases/connectivity_handler.dart';
import '../buffer/sentence_buffer.dart'; // 🆕 ENHANCED BUFFER
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

/// 🆕 ENHANCED: Transcription fixes for common speech-to-text errors
class TranscriptionFixes {
  static const Map<String, String> commonFixes = {
    // Verb tense corrections
    'intensify the training': 'intensifying the training',
    'by intensify': 'by intensifying',
    'begin the': 'began the',
    'start the': 'started the',

    // Number/plurality fixes
    '12 very ordinary man': '12 very ordinary men',
    'these man': 'these men',
    'those man': 'those men',

    // Common speech-to-text errors
    'peace record says': 'peace, the record says',
    'embarrassed that held': 'embarrassed that he held',
    'witness an argument': 'witnessed an argument',

    // Biblical/formal language corrections
    'jesus witness': 'Jesus witnessed',
    'jesus began': 'Jesus began',
    'the 12': 'the twelve',
  };

  static String apply(String text) {
    var corrected = text;

    // Apply specific fixes
    commonFixes.forEach((error, correction) {
      final regex = RegExp(error, caseSensitive: false);
      corrected = corrected.replaceAllMapped(regex, (match) {
        return _preserveCase(match.group(0)!, correction);
      });
    });

    // Pattern-based fixes
    corrected = _fixVerbTensePatterns(corrected);
    corrected = _fixPluralityPatterns(corrected);
    corrected = _fixCapitalizationPatterns(corrected);

    return corrected;
  }

  static String _preserveCase(String original, String replacement) {
    if (original.isEmpty || replacement.isEmpty) return replacement;
    if (original[0] == original[0].toUpperCase()) {
      return replacement[0].toUpperCase() + replacement.substring(1);
    }
    return replacement;
  }

  static String _fixVerbTensePatterns(String text) {
    return text.replaceAllMapped(
      RegExp(r'\bby (\w+)\b(?!\w*ing\b)', caseSensitive: false),
      (match) {
        final verb = match.group(1)!;
        const verbsNeedingIng = {
          'intensify',
          'train',
          'teach',
          'develop',
          'build',
          'create',
          'establish',
          'strengthen',
          'prepare',
        };

        if (verbsNeedingIng.contains(verb.toLowerCase())) {
          return 'by ${verb}ing';
        }
        return match.group(0)!;
      },
    );
  }

  static String _fixPluralityPatterns(String text) {
    return text.replaceAllMapped(
      RegExp(
        r'\b(\d+|twelve|eleven|ten|nine|eight|seven|six|five|four|three|two)\s+(\w+)\s+man\b',
        caseSensitive: false,
      ),
      (match) => '${match.group(1)} ${match.group(2)} men',
    );
  }

  static String _fixCapitalizationPatterns(String text) {
    var fixed = text;

    // Jesus should always be capitalized
    fixed = fixed.replaceAllMapped(
      RegExp(r'\bjesus\b', caseSensitive: false),
      (match) => 'Jesus',
    );

    // Fix sentence beginnings
    fixed = fixed.replaceAllMapped(
      RegExp(r'([.!?]\s+)([a-z])'),
      (match) => '${match.group(1)}${match.group(2)!.toUpperCase()}',
    );

    return fixed;
  }
}

/// 🆕 ENHANCED: Processing coordination to prevent overlaps
class ProcessingCoordinator {
  bool _isProcessing = false;
  DateTime? _lastProcessingStart;
  static const Duration _minProcessingInterval = Duration(seconds: 2);
  static const Duration _maxProcessingTime = Duration(seconds: 10);

  bool canStartProcessing() {
    if (_isProcessing) {
      print('⚠️ [ProcessingCoordinator] Already processing, skipping');
      return false;
    }

    if (_lastProcessingStart != null) {
      final timeSinceLastStart = DateTime.now().difference(
        _lastProcessingStart!,
      );
      if (timeSinceLastStart < _minProcessingInterval) {
        print(
          '⚠️ [ProcessingCoordinator] Too soon since last processing (${timeSinceLastStart.inMilliseconds}ms)',
        );
        return false;
      }
    }

    return true;
  }

  void startProcessing() {
    _isProcessing = true;
    _lastProcessingStart = DateTime.now();
    print('🔄 [ProcessingCoordinator] Processing started');
  }

  void completeProcessing() {
    if (_lastProcessingStart != null) {
      final processingTime = DateTime.now().difference(_lastProcessingStart!);
      print(
        '✅ [ProcessingCoordinator] Processing completed in ${processingTime.inMilliseconds}ms',
      );
    }
    _isProcessing = false;
  }

  bool isProcessingStuck() {
    if (!_isProcessing || _lastProcessingStart == null) return false;
    final processingTime = DateTime.now().difference(_lastProcessingStart!);
    return processingTime > _maxProcessingTime;
  }

  void forceReset() {
    print('🔧 [ProcessingCoordinator] Force resetting stuck processing');
    _isProcessing = false;
    _lastProcessingStart = null;
  }
}

/// 🆕 ENHANCED: Quality validation for output
class QualityValidator {
  static const int _minQualityLength = 15;
  static const int _maxReasonableLength = 300;
  static const double _minWordsPerSentence = 3.0;

  static QualityResult validate(String text) {
    final issues = <String>[];

    // Length checks
    if (text.trim().length < _minQualityLength) {
      issues.add('Too short (${text.length} chars)');
    }

    if (text.length > _maxReasonableLength) {
      issues.add('Very long (${text.length} chars)');
    }

    // Content quality checks
    final words = text.split(' ').where((w) => w.trim().isNotEmpty).length;
    final sentences =
        text.split(RegExp(r'[.!?]+')).where((s) => s.trim().isNotEmpty).length;

    if (sentences > 0) {
      final avgWordsPerSentence = words / sentences;
      if (avgWordsPerSentence < _minWordsPerSentence) {
        issues.add(
          'Very short sentences (avg ${avgWordsPerSentence.toStringAsFixed(1)} words/sentence)',
        );
      }
    }

    // Common transcription error patterns
    if (text.contains(RegExp(r'\b\d+\s+\w*\s+man\b'))) {
      issues.add('Possible plurality error');
    }

    if (text.contains(RegExp(r'\bby\s+\w+(?!ing\b)'))) {
      issues.add('Possible verb tense error');
    }

    // Quality score
    var qualityScore = 100;
    qualityScore -= issues.length * 10;
    if (text.length < 30) qualityScore -= 20;
    if (words < 8) qualityScore -= 15;

    final isAcceptable = qualityScore >= 70 && issues.length <= 2;

    return QualityResult(
      isAcceptable: isAcceptable,
      qualityScore: qualityScore,
      issues: issues,
    );
  }
}

class QualityResult {
  final bool isAcceptable;
  final int qualityScore;
  final List<String> issues;

  const QualityResult({
    required this.isAcceptable,
    required this.qualityScore,
    required this.issues,
  });

  @override
  String toString() {
    return 'QualityResult(score: $qualityScore, acceptable: $isAcceptable, issues: ${issues.length})';
  }
}

/// Enhanced SpeakerEngine with all quality improvements
class EnhancedSpeakerEngine {
  final IPermissionService _permission;
  final ISpeechToTextService _stt;
  final ITranslationService _translation;
  final ISessionService _session;
  final ISocketService _socket;
  final IConnectivityService _connectivity;
  final HermesLogger _log;

  // 🆕 ENHANCED: Processing services
  final LanguageToolService _grammar;
  final EnhancedSentenceBuffer _sentenceBuffer; // 🆕 ENHANCED BUFFER
  final BufferAnalytics _analytics;
  final ProcessingCoordinator _coordinator = ProcessingCoordinator(); // 🆕 NEW

  // Core state
  HermesSessionState _state = HermesSessionState.initial();
  StreamController<HermesSessionState>? _stateController;
  Stream<HermesSessionState> get stream =>
      _stateController?.stream ?? const Stream.empty();

  // Session management
  bool _isSessionActive = false;
  String _targetLanguageCode = '';

  // 🆕 ENHANCED: Optimized timing
  Timer? _processingTimer;
  Timer? _forceCheckTimer;
  static const Duration _processingInterval = Duration(seconds: 15);
  static const Duration _forceCheckInterval = Duration(seconds: 5);

  // Audience tracking
  int _audienceCount = 0;
  Map<String, int> _languageDistribution = {};

  // Socket subscription
  StreamSubscription<SocketEvent>? _socketSubscription;

  // Infrastructure
  late final StartSessionUseCase _startUseCase;
  late final ConnectivityHandlerUseCase _connHandler;

  EnhancedSpeakerEngine({
    required IPermissionService permission,
    required ISpeechToTextService stt,
    required ITranslationService translator,
    required ITextToSpeechService tts,
    required ISessionService session,
    required ISocketService socket,
    required IConnectivityService connectivity,
    required ILoggerService logger,
    required LanguageToolService grammar,
    required EnhancedSentenceBuffer sentenceBuffer, // 🆕 ENHANCED
    required BufferAnalytics analytics,
  }) : _permission = permission,
       _stt = stt,
       _translation = translator,
       _session = session,
       _socket = socket,
       _connectivity = connectivity,
       _log = HermesLogger(logger),
       _grammar = grammar,
       _sentenceBuffer = sentenceBuffer, // 🆕 ENHANCED
       _analytics = analytics {
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

  /// Starts speaker flow with enhanced processing pipeline
  Future<void> start({required String languageCode}) async {
    print('🎤 [SpeakerEngine] Starting ENHANCED speaker session...');

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
      _startEnhancedProcessingPipeline(); // 🆕 ENHANCED
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

  /// 🆕 ENHANCED: Initialize processing services
  Future<void> _initializeProcessingServices() async {
    print('🔧 [SpeakerEngine] Initializing ENHANCED processing services...');

    final grammarInitialized = await _grammar.initialize();
    if (!grammarInitialized) {
      print(
        '⚠️ [SpeakerEngine] Grammar service failed to initialize - continuing without grammar correction',
      );
    }

    _analytics.startSession();
    print('✅ [SpeakerEngine] Enhanced processing services initialized');
  }

  /// 🆕 ENHANCED: Start the optimized processing pipeline
  void _startEnhancedProcessingPipeline() {
    print('⏰ [SpeakerEngine] Starting ENHANCED 15-second processing timer...');

    _processingTimer?.cancel();
    _forceCheckTimer?.cancel();

    // Main 15-second timer
    _processingTimer = Timer.periodic(_processingInterval, (_) {
      _processAccumulatedText('timer');
    });

    // Enhanced force check every 5 seconds
    _forceCheckTimer = Timer.periodic(_forceCheckInterval, (_) {
      if (!_isSessionActive) return;

      // Check for stuck processing
      if (_coordinator.isProcessingStuck()) {
        _coordinator.forceReset();
      }

      // Check for force flush
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
      onResult: _handleEnhancedSpeechResult, // 🆕 ENHANCED
      onError: _handleSpeechError,
    );
  }

  /// 🆕 ENHANCED: Handle speech results with intelligent processing
  void _handleEnhancedSpeechResult(SpeechResult result) async {
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

    // 🆕 ENHANCED: Use intelligent transcript processing
    final naturalBreakText = _sentenceBuffer.processLatestTranscript(
      result.transcript,
    );

    if (naturalBreakText != null) {
      print(
        '🎯 [SpeakerEngine] Found natural break point, processing immediately...',
      );
      await _processAccumulatedText('natural_break');
    }
  }

  /// 🆕 ENHANCED: Process accumulated text with coordination and quality checks
  Future<void> _processAccumulatedText(String reason) async {
    if (!_isSessionActive) return;

    // Check processing coordination
    if (!_coordinator.canStartProcessing()) {
      return;
    }

    String? textToProcess;
    if (reason == 'timer') {
      textToProcess = _sentenceBuffer.flushForTimer();
    } else {
      textToProcess = _sentenceBuffer.flushForced();
    }

    _coordinator.startProcessing();

    try {
      print(
        '⏰ [SpeakerEngine] Processing accumulated text ($reason): "${textToProcess.substring(0, textToProcess.length.clamp(0, 50))}..."',
      );

      // 🆕 ENHANCED: Quality validation
      final quality = QualityValidator.validate(textToProcess);
      print('📊 [QualityValidator] $quality');

      if (!quality.isAcceptable && reason != 'force') {
        print(
          '🚫 [SpeakerEngine] Text quality not acceptable for $reason processing',
        );
        return;
      }

      await _processTextEnhanced(textToProcess, reason);
    } finally {
      _coordinator.completeProcessing();
    }
  }

  /// 🆕 ENHANCED: Complete processing pipeline with transcription fixes
  Future<void> _processTextEnhanced(String text, String reason) async {
    if (!_isSessionActive || text.trim().isEmpty) return;

    final processingStart = DateTime.now();
    print(
      '🔄 [SpeakerEngine] Starting ENHANCED processing pipeline for: "${text.substring(0, text.length.clamp(0, 50))}..."',
    );

    try {
      _emit(_state.copyWith(status: HermesStatus.translating));

      // Step 0: 🆕 ENHANCED: Apply transcription fixes
      final fixedText = TranscriptionFixes.apply(text);
      if (fixedText != text) {
        print('🔧 [TranscriptionFixes] Applied fixes');
        print(
          '   Original: "${text.substring(0, text.length.clamp(0, 40))}..."',
        );
        print(
          '   Fixed: "${fixedText.substring(0, fixedText.length.clamp(0, 40))}..."',
        );
      }

      // Step 1: Grammar correction
      final grammarStart = DateTime.now();
      final correctedText = await _grammar.correctGrammar(fixedText);
      final grammarLatency = DateTime.now().difference(grammarStart);

      print(
        '📝 [SpeakerEngine] Grammar correction took ${grammarLatency.inMilliseconds}ms',
      );
      if (correctedText != fixedText) {
        print('✏️ [SpeakerEngine] Grammar corrections applied');
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

      // Step 4: 🆕 ENHANCED: Emit processed sentence for permanent chat display
      _emit(
        _state.copyWith(
          status: HermesStatus.listening,
          lastProcessedSentence: correctedText, // Add to permanent chat
        ),
      );

      // Update analytics
      final endToEndLatency = DateTime.now().difference(processingStart);
      _analytics.logBufferProcessed(
        textLength: text.length,
        sentenceCount: _countSentences(text),
        hadPunctuation: reason == 'punctuation' || reason == 'natural_break',
        wasForcedSend: reason == 'force',
        grammarLatency: grammarLatency,
        translationLatency: translationLatency,
      );

      print(
        '✅ [SpeakerEngine] ENHANCED processing complete in ${endToEndLatency.inMilliseconds}ms',
      );
    } catch (e, stackTrace) {
      print('❌ [SpeakerEngine] Processing failed: $e');
      _log.error('Text processing failed', error: e, stackTrace: stackTrace);

      // Record failure in analytics
      _analytics.logBufferProcessed(
        textLength: text.length,
        sentenceCount: _countSentences(text),
        hadPunctuation: reason == 'punctuation' || reason == 'natural_break',
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

  /// Broadcast translation to all audience members
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
    print('🛑 [SpeakerEngine] Stopping ENHANCED speaker session...');

    _isSessionActive = false;

    // Stop processing timers
    _processingTimer?.cancel();
    _forceCheckTimer?.cancel();
    _processingTimer = null;
    _forceCheckTimer = null;

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
    _sentenceBuffer
        .clearAll(); // 🆕 ENHANCED: Clear everything including accumulation
    _audienceCount = 0;
    _languageDistribution = {};

    _emit(_state.copyWith(status: HermesStatus.idle));
    await Future.delayed(const Duration(milliseconds: 50));
    print('✅ [SpeakerEngine] ENHANCED speaker session stopped');
  }

  Future<void> pause() async {
    print('⏸️ [SpeakerEngine] Pausing session...');
    _processingTimer?.cancel();
    _forceCheckTimer?.cancel();
    await _stt.stopListening();
    _emit(_state.copyWith(status: HermesStatus.paused));
  }

  Future<void> resume() async {
    print('▶️ [SpeakerEngine] Resuming session...');
    if (_isSessionActive) {
      _startEnhancedProcessingPipeline(); // 🆕 ENHANCED
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
    print('🗑️ [SpeakerEngine] Disposing ENHANCED speaker engine...');

    _isSessionActive = false;
    _processingTimer?.cancel();
    _forceCheckTimer?.cancel();
    _stt.dispose();
    _socketSubscription?.cancel();
    _connHandler.dispose();
    _grammar.dispose();

    if (_stateController != null && !_stateController!.isClosed) {
      _stateController!.close();
    }
    _stateController = null;

    print('✅ [SpeakerEngine] ENHANCED speaker engine disposed');
  }
}
