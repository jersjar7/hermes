// lib/core/hermes_engine/speaker/speaker_engine.dart
// REFACTORED: Clean, maintainable speaker engine using orchestrated components

import 'dart:async';

import 'package:hermes/core/hermes_engine/buffer/buffer_analytics.dart';
import 'package:hermes/core/hermes_engine/buffer/sentence_buffer.dart';
import 'package:hermes/core/services/logger/logger_service.dart';
import 'package:hermes/core/services/speech_to_text/speech_to_text_service.dart';
import 'package:hermes/core/services/translation/translation_service.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/core/services/socket/socket_service.dart';
import 'package:hermes/core/services/permission/permission_service.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';
import 'package:hermes/core/services/grammar/language_tool_service.dart';

import 'config/speaker_config.dart';
import 'state/speaker_session_state.dart';
import 'handlers/duplicate_detection_handler.dart';
import 'handlers/audience_handler.dart';
import 'processors/speech_processor.dart';
import 'processors/text_processor.dart';
import 'processors/broadcast_processor.dart';
import 'usecases/handle_speech_result_usecase.dart';
import 'usecases/process_accumulated_text_usecase.dart';
import 'usecases/manage_processing_pipeline_usecase.dart';
import '../state/hermes_status.dart';
import '../usecases/start_session.dart';
import '../usecases/connectivity_handler.dart';
import '../utils/log.dart';

/// Clean, maintainable SpeakerEngine with orchestrated architecture
class SpeakerEngine {
  // === CORE DEPENDENCIES ===
  final IPermissionService _permission;
  final ISpeechToTextService _stt;
  final ITranslationService _translation;
  final ISessionService _session;
  final ISocketService _socket;
  final IConnectivityService _connectivity;
  final ILoggerService _logger; // Keep original logger service
  final HermesLogger _log;

  // === PROCESSING COMPONENTS ===
  late final SentenceBuffer _sentenceBuffer;
  late final BufferAnalytics _analytics;
  late final DuplicateDetectionHandler _duplicateDetection;
  late final AudienceHandler _audienceHandler;
  late final SpeechProcessor _speechProcessor;
  late final TextProcessor _textProcessor;
  late final BroadcastProcessor _broadcastProcessor;

  // === USE CASES ===
  late final HandleSpeechResultUseCase _speechResultHandler;
  late final ProcessAccumulatedTextUseCase _textProcessingHandler;
  late final ManageProcessingPipelineUseCase _pipelineManager;

  // === INFRASTRUCTURE ===
  late final StartSessionUseCase _startUseCase;
  late final ConnectivityHandlerUseCase _connHandler;

  // === STATE MANAGEMENT ===
  SpeakerSessionState _state = SpeakerSessionState.initial();
  StreamController<SpeakerSessionState>? _stateController;
  Stream<SpeakerSessionState> get stream =>
      _stateController?.stream ?? const Stream.empty();

  // === SESSION TRACKING ===
  bool _isSessionActive = false;
  String _targetLanguageCode = '';

  // === EVENT SUBSCRIPTIONS ===
  StreamSubscription<PipelineManagementEvent>? _pipelineSubscription;
  StreamSubscription<SpeechResultHandlingEvent>? _speechResultSubscription;
  StreamSubscription<AccumulatedTextProcessingEvent>?
  _textProcessingSubscription;
  StreamSubscription<AudienceInfo>? _audienceSubscription;

  SpeakerEngine({
    required IPermissionService permission,
    required ISpeechToTextService stt,
    required ITranslationService translator,
    required ITextToSpeechService tts,
    required ISessionService session,
    required ISocketService socket,
    required IConnectivityService connectivity,
    required ILoggerService logger,
    required LanguageToolService grammar,
    required SentenceBuffer sentenceBuffer,
    required BufferAnalytics analytics,
  }) : _permission = permission,
       _stt = stt,
       _translation = translator,
       _session = session,
       _socket = socket,
       _connectivity = connectivity,
       _logger = logger, // Store original logger
       _log = HermesLogger(
         logger,
         'SpeakerEngine',
       ), // Create HermesLogger from it
       _sentenceBuffer = sentenceBuffer,
       _analytics = analytics {
    _initializeComponents();
    _ensureStateController();
  }

  /// Initializes all components and their dependencies
  void _initializeComponents() {
    print('🔧 [SpeakerEngine] Initializing components...');

    // === HANDLERS ===
    _duplicateDetection = DuplicateDetectionHandler();
    _audienceHandler = AudienceHandler(logger: _logger);

    // === PROCESSORS ===
    _speechProcessor = SpeechProcessor(stt: _stt, logger: _logger);

    _textProcessor = TextProcessor(
      grammar: LanguageToolService(), // This should be injected
      translation: _translation,
      duplicateDetection: _duplicateDetection,
      logger: _logger,
    );

    _broadcastProcessor = BroadcastProcessor(
      socket: _socket,
      session: _session,
      audienceHandler: _audienceHandler,
      logger: _logger,
    );

    // === USE CASES ===
    _speechResultHandler = HandleSpeechResultUseCase(
      sentenceBuffer: _sentenceBuffer,
      logger: _logger,
    );

    _textProcessingHandler = ProcessAccumulatedTextUseCase(
      textProcessor: _textProcessor,
      broadcastProcessor: _broadcastProcessor,
      sentenceBuffer: _sentenceBuffer,
      logger: _logger,
    );

    _pipelineManager = ManageProcessingPipelineUseCase(
      speechProcessor: _speechProcessor,
      textProcessor: _textProcessor,
      broadcastProcessor: _broadcastProcessor,
      audienceHandler: _audienceHandler,
      speechResultHandler: _speechResultHandler,
      textProcessingHandler: _textProcessingHandler,
      logger: _logger,
    );

    // === INFRASTRUCTURE ===
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

    print('✅ [SpeakerEngine] Components initialized');
  }

  /// Ensures state controller is available
  void _ensureStateController() {
    if (_stateController == null || _stateController!.isClosed) {
      _stateController?.close();
      _stateController = StreamController<SpeakerSessionState>.broadcast();
      print('🔄 [SpeakerEngine] Created new state controller');
    }
  }

  /// Starts speaker session with complete processing pipeline
  Future<void> start({required String languageCode}) async {
    print('🎤 [SpeakerEngine] Starting REFACTORED speaker session...');

    try {
      _ensureStateController();
      _targetLanguageCode = languageCode;
      _emit(_state.copyWith(status: HermesStatus.buffering));

      // === PHASE 1: SESSION SETUP ===
      await _setupSession(languageCode);

      // === PHASE 2: PIPELINE INITIALIZATION ===
      await _initializePipeline(languageCode);

      // === PHASE 3: EVENT SUBSCRIPTIONS ===
      _subscribeToEvents();

      // === PHASE 4: START PROCESSING ===
      await _startProcessing();

      _isSessionActive = true;
      print('✅ [SpeakerEngine] Speaker session started successfully');
    } catch (e, stackTrace) {
      print('❌ [SpeakerEngine] Failed to start session: $e');

      _log.error(
        'Speaker session start failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'StartError',
      );

      _emit(
        _state.copyWith(
          status: HermesStatus.error,
          errorMessage: 'Failed to start session: $e',
        ),
      );

      await _emergencyCleanup();
      rethrow;
    }
  }

  /// Sets up the session infrastructure
  Future<void> _setupSession(String languageCode) async {
    print('🚀 [SpeakerEngine] Setting up session infrastructure...');

    // Start session and connectivity monitoring
    await _startUseCase.execute(isSpeaker: true, languageCode: languageCode);
    _connHandler.startMonitoring(
      onOffline: _handleOffline,
      onOnline: _handleOnline,
    );

    // Start analytics session
    _analytics.startSession();

    print('✅ [SpeakerEngine] Session infrastructure ready');
  }

  /// Initializes the processing pipeline
  Future<void> _initializePipeline(String languageCode) async {
    print('🔧 [SpeakerEngine] Initializing processing pipeline...');

    _emit(_state.copyWith(status: HermesStatus.buffering));

    await _pipelineManager.initializePipeline(languageCode);

    print('✅ [SpeakerEngine] Pipeline initialized');
  }

  /// Subscribes to all component events
  void _subscribeToEvents() {
    print('🔗 [SpeakerEngine] Setting up event subscriptions...');

    // === PIPELINE MANAGEMENT EVENTS ===
    _pipelineSubscription = _pipelineManager.events.listen(
      _handlePipelineEvent,
      onError: _handleEventError,
    );

    // === SPEECH RESULT EVENTS ===
    _speechResultSubscription = _speechResultHandler.events.listen(
      _handleSpeechResultEvent,
      onError: _handleEventError,
    );

    // === TEXT PROCESSING EVENTS ===
    _textProcessingSubscription = _textProcessingHandler.events.listen(
      _handleTextProcessingEvent,
      onError: _handleEventError,
    );

    // === AUDIENCE EVENTS ===
    _audienceSubscription = _audienceHandler.audienceStream.listen(
      _handleAudienceUpdate,
      onError: _handleEventError,
    );

    print('✅ [SpeakerEngine] Event subscriptions ready');
  }

  /// Starts the processing pipeline
  Future<void> _startProcessing() async {
    print('🎬 [SpeakerEngine] Starting processing pipeline...');

    await _pipelineManager.startPipeline();

    print('✅ [SpeakerEngine] Processing pipeline started');
  }

  /// Handles pipeline management events
  void _handlePipelineEvent(PipelineManagementEvent event) {
    if (event is PipelineInitializedEvent) {
      _emit(
        _state.copyWith(
          status: HermesStatus.buffering,
          targetLanguageCode: event.targetLanguageCode,
        ),
      );
    } else if (event is PipelineStartedEvent) {
      _emit(_state.copyWith(status: HermesStatus.listening));
    } else if (event is PipelinePausedEvent) {
      _emit(_state.copyWith(status: HermesStatus.paused));
    } else if (event is PipelineResumedEvent) {
      _emit(_state.copyWith(status: HermesStatus.listening));
    } else if (event is PipelineErrorEvent) {
      _emit(
        _state.copyWith(
          status: HermesStatus.error,
          errorMessage: 'Pipeline error in ${event.component}: ${event.error}',
        ),
      );
    } else if (event is PipelineStateSyncEvent) {
      // Merge pipeline state with current state
      _emit(
        _state.copyWith(
          audienceCount: event.currentState.audienceCount,
          languageDistribution: event.currentState.languageDistribution,
        ),
      );
    }
  }

  /// Handles speech result events for UI updates
  void _handleSpeechResultEvent(SpeechResultHandlingEvent event) {
    if (event is TranscriptUpdatedEvent) {
      _emit(
        _state.copyWith(
          status: HermesStatus.listening,
          lastTranscript: event.transcript,
        ),
      );
    } else if (event is CompleteSentencesDetectedEvent) {
      // Complete sentences detected - processing will happen automatically
      print(
        '🎯 [SpeakerEngine] Complete sentences detected, processing initiated',
      );
    } else if (event is BufferForceFlushEvent) {
      // Buffer force flush - processing will happen automatically
      print('⚠️ [SpeakerEngine] Buffer force flush: ${event.reason}');
    }
  }

  /// Handles text processing workflow events
  void _handleTextProcessingEvent(AccumulatedTextProcessingEvent event) {
    if (event is ProcessingCycleCompletedEvent) {
      final result = event.result;

      // Update state with processed content
      if (result.processingType.shouldEmitToUI) {
        _emit(
          _state.copyWith(
            lastProcessedSentence: result.correctedText,
            lastTranslation: result.translatedText,
            isReplacement: result.isReplacement,
            replacedText: result.replacedText,
            status: HermesStatus.listening,
          ),
        );
      } else {
        // For replacements, just ensure we're in listening state
        _emit(_state.copyWith(status: HermesStatus.listening));
      }

      print('✅ [SpeakerEngine] Text processed and state updated');
    } else if (event is ProcessingCycleFailedEvent) {
      print('❌ [SpeakerEngine] Text processing failed: ${event.error}');
      // Continue listening despite processing error
      _emit(_state.copyWith(status: HermesStatus.listening));
    }
  }

  /// Handles audience updates
  void _handleAudienceUpdate(AudienceInfo audienceInfo) {
    _emit(
      _state.copyWith(
        audienceCount: audienceInfo.totalListeners,
        languageDistribution: audienceInfo.languageDistribution,
      ),
    );
  }

  /// Handles event stream errors
  void _handleEventError(dynamic error) {
    print('❌ [SpeakerEngine] Event stream error: $error');
    _log.error('Event stream error', error: error, tag: 'EventError');
  }

  /// Handles connectivity offline
  void _handleOffline() {
    print('📵 [SpeakerEngine] Going offline - pausing session');
    _emit(_state.copyWith(status: HermesStatus.paused));
  }

  /// Handles connectivity online
  void _handleOnline() {
    print('📶 [SpeakerEngine] Coming online - resuming session');
    if (_isSessionActive) {
      _pipelineManager.resumePipeline();
    }
  }

  /// Stops the speaker session with graceful cleanup
  Future<void> stop() async {
    print('🛑 [SpeakerEngine] Stopping speaker session...');

    _isSessionActive = false;

    try {
      // === PHASE 1: STOP PIPELINE ===
      await _pipelineManager.stopPipeline();

      // === PHASE 2: CLEANUP INFRASTRUCTURE ===
      await _cleanupInfrastructure();

      // === PHASE 3: FINAL STATE UPDATE ===
      _emit(_state.copyWith(status: HermesStatus.idle));
      await Future.delayed(SpeakerConfig.stateEmissionDelay);

      print('✅ [SpeakerEngine] Speaker session stopped successfully');
    } catch (e, stackTrace) {
      print('❌ [SpeakerEngine] Error during stop: $e');

      _log.error(
        'Error stopping speaker session',
        error: e,
        stackTrace: stackTrace,
        tag: 'StopError',
      );

      // Force emergency cleanup
      await _emergencyCleanup();
    }
  }

  /// Cleans up infrastructure components
  Future<void> _cleanupInfrastructure() async {
    print('🧹 [SpeakerEngine] Cleaning up infrastructure...');

    // Cancel event subscriptions
    await _pipelineSubscription?.cancel();
    await _speechResultSubscription?.cancel();
    await _textProcessingSubscription?.cancel();
    await _audienceSubscription?.cancel();

    // Stop connectivity monitoring
    _connHandler.dispose();

    // Disconnect socket
    try {
      await _socket.disconnect();
    } catch (e) {
      print('⚠️ [SpeakerEngine] Error disconnecting socket: $e');
    }

    // Clear buffers and reset handlers
    _sentenceBuffer.clear();
    _duplicateDetection.clearCache();
    _audienceHandler.reset();

    print('✅ [SpeakerEngine] Infrastructure cleanup completed');
  }

  /// Emergency cleanup for error conditions
  Future<void> _emergencyCleanup() async {
    print('🚨 [SpeakerEngine] Performing emergency cleanup...');

    _isSessionActive = false;

    try {
      await _pipelineSubscription?.cancel();
      await _speechResultSubscription?.cancel();
      await _textProcessingSubscription?.cancel();
      await _audienceSubscription?.cancel();

      _connHandler.dispose();
      _sentenceBuffer.clear();
      _duplicateDetection.clearCache();

      _emit(_state.copyWith(status: HermesStatus.idle));
    } catch (e) {
      print('⚠️ [SpeakerEngine] Error during emergency cleanup: $e');
    }
  }

  /// Pauses the speaker session
  Future<void> pause() async {
    print('⏸️ [SpeakerEngine] Pausing session...');

    if (_pipelineManager.currentStatus.canPause) {
      await _pipelineManager.pausePipeline(reason: 'manual');
    }
  }

  /// Resumes the speaker session
  Future<void> resume() async {
    print('▶️ [SpeakerEngine] Resuming session...');

    if (_pipelineManager.currentStatus.canResume) {
      await _pipelineManager.resumePipeline();
    }
  }

  /// Current audience count
  int get audienceCount => _audienceHandler.audienceCount;

  /// Current language distribution
  Map<String, int> get languageDistribution =>
      _audienceHandler.languageDistribution;

  /// Emits state update
  void _emit(SpeakerSessionState newState) {
    if (_stateController != null && !_stateController!.isClosed) {
      _state = newState;
      _stateController!.add(newState);
      print('🔄 [SpeakerEngine] State: ${newState.status}');
    } else {
      print('⚠️ [SpeakerEngine] Cannot emit state - controller closed or null');
    }
  }

  /// Gets comprehensive session statistics
  Map<String, dynamic> getSessionStats() {
    return {
      'isActive': _isSessionActive,
      'targetLanguage': _targetLanguageCode,
      'currentState': _state.status.toString(),
      'pipelineStats': _pipelineManager.getPipelineStats(),
      'audienceStats': _audienceHandler.getAudienceStats(),
      'bufferStats': _speechResultHandler.getBufferAnalytics(),
    };
  }

  /// Disposes of all resources
  void dispose() {
    print('🗑️ [SpeakerEngine] Disposing speaker engine...');

    _isSessionActive = false;

    // Dispose pipeline manager (will handle all processors)
    _pipelineManager.dispose();

    // Dispose handlers
    _duplicateDetection.dispose();
    _audienceHandler.dispose();

    // Dispose infrastructure
    _connHandler.dispose();
    _stt.dispose();

    // Close state controller
    if (_stateController != null && !_stateController!.isClosed) {
      _stateController!.close();
    }
    _stateController = null;

    print('✅ [SpeakerEngine] Speaker engine disposed');
  }
}
