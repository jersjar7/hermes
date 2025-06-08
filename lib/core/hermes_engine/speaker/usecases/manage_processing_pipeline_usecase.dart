// lib/core/hermes_engine/speaker/usecases/manage_processing_pipeline_usecase.dart
// Complete grammar→translation→broadcast pipeline management

import 'dart:async';

import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/hermes_engine/utils/log.dart';
import 'package:hermes/core/services/logger/logger_service.dart';

import '../config/speaker_config.dart';
import '../state/speaker_session_state.dart';
import '../processors/speech_processor.dart';
import '../processors/text_processor.dart';
import '../processors/broadcast_processor.dart';
import '../handlers/audience_handler.dart';
import 'handle_speech_result_usecase.dart';
import 'process_accumulated_text_usecase.dart';

/// Pipeline management events
abstract class PipelineManagementEvent {}

/// Pipeline initialization started
class PipelineInitializationStartedEvent extends PipelineManagementEvent {
  final String targetLanguageCode;
  final DateTime timestamp;

  PipelineInitializationStartedEvent(this.targetLanguageCode, this.timestamp);
}

/// Pipeline fully initialized and ready
class PipelineInitializedEvent extends PipelineManagementEvent {
  final String targetLanguageCode;
  final bool grammarServiceAvailable;
  final Duration initializationTime;

  PipelineInitializedEvent(
    this.targetLanguageCode,
    this.grammarServiceAvailable,
    this.initializationTime,
  );
}

/// Pipeline started and actively processing
class PipelineStartedEvent extends PipelineManagementEvent {
  final String targetLanguageCode;
  final SpeechProcessingState speechState;
  final BroadcastStatus broadcastStatus;

  PipelineStartedEvent(
    this.targetLanguageCode,
    this.speechState,
    this.broadcastStatus,
  );
}

/// Pipeline stopped
class PipelineStoppedEvent extends PipelineManagementEvent {
  final Duration sessionDuration;
  final PipelineSessionStats finalStats;

  PipelineStoppedEvent(this.sessionDuration, this.finalStats);
}

/// Pipeline paused
class PipelinePausedEvent extends PipelineManagementEvent {
  final String reason;

  PipelinePausedEvent(this.reason);
}

/// Pipeline resumed
class PipelineResumedEvent extends PipelineManagementEvent {
  final Duration pauseDuration;

  PipelineResumedEvent(this.pauseDuration);
}

/// Pipeline error occurred
class PipelineErrorEvent extends PipelineManagementEvent {
  final String component;
  final Exception error;
  final bool recoverable;

  PipelineErrorEvent(this.component, this.error, this.recoverable);
}

/// Pipeline state synchronization completed
class PipelineStateSyncEvent extends PipelineManagementEvent {
  final SpeakerSessionState currentState;
  final Map<String, dynamic> componentStates;

  PipelineStateSyncEvent(this.currentState, this.componentStates);
}

/// Overall pipeline session statistics
class PipelineSessionStats {
  final Duration sessionDuration;
  final int totalSpeechResults;
  final int totalTextProcessed;
  final int totalBroadcasts;
  final int duplicatesSkipped;
  final Map<String, dynamic> speechStats;
  final Map<String, dynamic> textStats;
  final Map<String, dynamic> broadcastStats;
  final Map<String, dynamic> bufferStats;

  const PipelineSessionStats({
    required this.sessionDuration,
    required this.totalSpeechResults,
    required this.totalTextProcessed,
    required this.totalBroadcasts,
    required this.duplicatesSkipped,
    required this.speechStats,
    required this.textStats,
    required this.broadcastStats,
    required this.bufferStats,
  });

  double get processingEfficiency {
    if (totalSpeechResults == 0) return 1.0;
    return (totalTextProcessed / totalSpeechResults).clamp(0.0, 1.0);
  }

  double get broadcastSuccessRate {
    if (totalBroadcasts == 0) return 1.0;
    final successfulBroadcasts = broadcastStats['successfulBroadcasts'] ?? 0;
    return (successfulBroadcasts / totalBroadcasts).clamp(0.0, 1.0);
  }
}

/// Current pipeline status
enum PipelineStatus {
  idle,
  initializing,
  ready,
  active,
  paused,
  stopping,
  error,
}

/// Extension methods for PipelineStatus
extension PipelineStatusExtension on PipelineStatus {
  String get description {
    switch (this) {
      case PipelineStatus.idle:
        return 'Idle';
      case PipelineStatus.initializing:
        return 'Initializing';
      case PipelineStatus.ready:
        return 'Ready';
      case PipelineStatus.active:
        return 'Active';
      case PipelineStatus.paused:
        return 'Paused';
      case PipelineStatus.stopping:
        return 'Stopping';
      case PipelineStatus.error:
        return 'Error';
    }
  }

  bool get canStart =>
      this == PipelineStatus.ready || this == PipelineStatus.idle;
  bool get canStop =>
      this == PipelineStatus.active || this == PipelineStatus.paused;
  bool get canPause => this == PipelineStatus.active;
  bool get canResume => this == PipelineStatus.paused;
  bool get isActive => this == PipelineStatus.active;
}

/// Manages the complete speech processing pipeline
class ManageProcessingPipelineUseCase {
  /// Core processors
  final SpeechProcessor _speechProcessor;
  final TextProcessor _textProcessor;
  final BroadcastProcessor _broadcastProcessor;
  final AudienceHandler _audienceHandler;

  /// Use cases for specific workflows
  final HandleSpeechResultUseCase _speechResultHandler;
  final ProcessAccumulatedTextUseCase _textProcessingHandler;

  /// Logger for debugging and monitoring
  final HermesLogger _log;

  /// Stream controller for pipeline management events
  final StreamController<PipelineManagementEvent> _eventController =
      StreamController<PipelineManagementEvent>.broadcast();

  /// Current pipeline status
  PipelineStatus _currentStatus = PipelineStatus.idle;

  /// Session tracking
  DateTime? _sessionStartTime;
  DateTime? _pauseStartTime;
  Duration _totalPauseDuration = Duration.zero;
  String? _currentTargetLanguage;

  /// Event subscriptions
  StreamSubscription<SpeechProcessingEvent>? _speechSubscription;
  StreamSubscription<TextProcessingEvent>? _textSubscription;
  StreamSubscription<BroadcastEvent>? _broadcastSubscription;
  StreamSubscription<SpeechResultHandlingEvent>? _speechResultSubscription;
  StreamSubscription<AccumulatedTextProcessingEvent>?
  _textProcessingSubscription;

  ManageProcessingPipelineUseCase({
    required SpeechProcessor speechProcessor,
    required TextProcessor textProcessor,
    required BroadcastProcessor broadcastProcessor,
    required AudienceHandler audienceHandler,
    required HandleSpeechResultUseCase speechResultHandler,
    required ProcessAccumulatedTextUseCase textProcessingHandler,
    required ILoggerService logger,
  }) : _speechProcessor = speechProcessor,
       _textProcessor = textProcessor,
       _broadcastProcessor = broadcastProcessor,
       _audienceHandler = audienceHandler,
       _speechResultHandler = speechResultHandler,
       _textProcessingHandler = textProcessingHandler,
       _log = HermesLogger(logger, 'PipelineManager');

  /// Stream of pipeline management events
  Stream<PipelineManagementEvent> get events => _eventController.stream;

  /// Current pipeline status
  PipelineStatus get currentStatus => _currentStatus;

  /// Whether pipeline is currently active
  bool get isActive => _currentStatus.isActive;

  /// Current session duration
  Duration get sessionDuration {
    if (_sessionStartTime == null) return Duration.zero;
    return DateTime.now().difference(_sessionStartTime!) - _totalPauseDuration;
  }

  /// Initializes the complete processing pipeline
  Future<void> initializePipeline(String targetLanguageCode) async {
    if (!SpeakerConfig.isValidLanguageCode(targetLanguageCode)) {
      throw ArgumentError('Invalid language code: $targetLanguageCode');
    }

    print(
      '🚀 [PipelineManager] Initializing processing pipeline for language: $targetLanguageCode',
    );

    final initStart = DateTime.now();
    _setStatus(PipelineStatus.initializing);
    _currentTargetLanguage = targetLanguageCode;

    _emitEvent(
      PipelineInitializationStartedEvent(targetLanguageCode, initStart),
    );

    try {
      // Initialize text processor with target language
      await _textProcessor.initialize(targetLanguageCode);

      // Set up event subscriptions
      _subscribeToEvents();

      final initTime = DateTime.now().difference(initStart);

      _setStatus(PipelineStatus.ready);

      print(
        '✅ [PipelineManager] Pipeline initialized in ${initTime.inMilliseconds}ms',
      );

      _emitEvent(
        PipelineInitializedEvent(
          targetLanguageCode,
          _textProcessor.isGrammarServiceAvailable,
          initTime,
        ),
      );

      _log.info(
        'Pipeline initialized successfully for $targetLanguageCode (${initTime.inMilliseconds}ms)',
        tag: 'PipelineInit',
      );
    } catch (e, stackTrace) {
      print('❌ [PipelineManager] Pipeline initialization failed: $e');

      _log.error(
        'Pipeline initialization failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'InitError',
      );

      _setStatus(PipelineStatus.error);
      _emitEvent(
        PipelineErrorEvent('Initialization', Exception(e.toString()), false),
      );

      rethrow;
    }
  }

  /// Starts the complete processing pipeline
  Future<void> startPipeline() async {
    if (!_currentStatus.canStart) {
      print(
        '⚠️ [PipelineManager] Cannot start - current status: ${_currentStatus.description}',
      );
      return;
    }

    if (_currentTargetLanguage == null) {
      throw StateError(
        'Pipeline not initialized - call initializePipeline() first',
      );
    }

    print('🎬 [PipelineManager] Starting processing pipeline...');

    _sessionStartTime = DateTime.now();
    _totalPauseDuration = Duration.zero;

    try {
      // Start speech recognition
      await _speechProcessor.startListening(
        languageCode: _currentTargetLanguage!,
      );

      // Start automatic text processing
      _textProcessingHandler.startAutomaticProcessing();

      _setStatus(PipelineStatus.active);

      _emitEvent(
        PipelineStartedEvent(
          _currentTargetLanguage!,
          _speechProcessor.currentState,
          _broadcastProcessor.currentStatus,
        ),
      );

      print('✅ [PipelineManager] Pipeline started successfully');
      _log.info('Processing pipeline started', tag: 'PipelineStart');
    } catch (e, stackTrace) {
      print('❌ [PipelineManager] Failed to start pipeline: $e');

      _log.error(
        'Failed to start pipeline',
        error: e,
        stackTrace: stackTrace,
        tag: 'StartError',
      );

      _setStatus(PipelineStatus.error);
      _emitEvent(PipelineErrorEvent('Start', Exception(e.toString()), true));

      // Attempt cleanup
      await _emergencyStop();
      rethrow;
    }
  }

  /// Stops the complete processing pipeline
  Future<void> stopPipeline() async {
    if (!_currentStatus.canStop) {
      print(
        '⚠️ [PipelineManager] Cannot stop - current status: ${_currentStatus.description}',
      );
      return;
    }

    print('🛑 [PipelineManager] Stopping processing pipeline...');
    _setStatus(PipelineStatus.stopping);

    try {
      // Stop automatic text processing
      _textProcessingHandler.stopAutomaticProcessing();

      // Process any remaining accumulated text
      await _textProcessingHandler.processAccumulatedText(
        ProcessingTriggerReason.stop,
      );

      // Stop speech recognition
      await _speechProcessor.stopListening();

      // Calculate final statistics
      final finalStats = _calculateFinalStats();
      final totalSessionDuration = sessionDuration;

      _setStatus(PipelineStatus.idle);

      _emitEvent(PipelineStoppedEvent(totalSessionDuration, finalStats));

      print('✅ [PipelineManager] Pipeline stopped successfully');
      print('   Session duration: ${totalSessionDuration.inSeconds}s');

      _log.info(
        'Processing pipeline stopped (session: ${totalSessionDuration.inSeconds}s)',
        tag: 'PipelineStop',
      );

      // Reset session tracking
      _sessionStartTime = null;
      _pauseStartTime = null;
      _totalPauseDuration = Duration.zero;
    } catch (e, stackTrace) {
      print('❌ [PipelineManager] Error stopping pipeline: $e');

      _log.error(
        'Error stopping pipeline',
        error: e,
        stackTrace: stackTrace,
        tag: 'StopError',
      );

      // Force emergency stop
      await _emergencyStop();
    }
  }

  /// Pauses the processing pipeline
  Future<void> pausePipeline({String reason = 'manual'}) async {
    if (!_currentStatus.canPause) {
      print(
        '⚠️ [PipelineManager] Cannot pause - current status: ${_currentStatus.description}',
      );
      return;
    }

    print('⏸️ [PipelineManager] Pausing pipeline: $reason');

    _pauseStartTime = DateTime.now();

    // Pause speech recognition
    await _speechProcessor.pause();

    // Stop automatic processing
    _textProcessingHandler.stopAutomaticProcessing();

    _setStatus(PipelineStatus.paused);
    _emitEvent(PipelinePausedEvent(reason));

    _log.info('Pipeline paused: $reason', tag: 'PipelinePause');
  }

  /// Resumes the processing pipeline
  Future<void> resumePipeline() async {
    if (!_currentStatus.canResume) {
      print(
        '⚠️ [PipelineManager] Cannot resume - current status: ${_currentStatus.description}',
      );
      return;
    }

    print('▶️ [PipelineManager] Resuming pipeline...');

    // Calculate pause duration
    Duration pauseDuration = Duration.zero;
    if (_pauseStartTime != null) {
      pauseDuration = DateTime.now().difference(_pauseStartTime!);
      _totalPauseDuration += pauseDuration;
      _pauseStartTime = null;
    }

    // Resume speech recognition
    await _speechProcessor.resume();

    // Restart automatic processing
    _textProcessingHandler.startAutomaticProcessing();

    _setStatus(PipelineStatus.active);
    _emitEvent(PipelineResumedEvent(pauseDuration));

    print(
      '✅ [PipelineManager] Pipeline resumed after ${pauseDuration.inSeconds}s pause',
    );
    _log.info(
      'Pipeline resumed (paused for ${pauseDuration.inSeconds}s)',
      tag: 'PipelineResume',
    );
  }

  /// Sets up event subscriptions to coordinate processors
  void _subscribeToEvents() {
    print('🔗 [PipelineManager] Setting up event subscriptions...');

    // Subscribe to speech processing events
    _speechSubscription = _speechProcessor.events.listen(
      _handleSpeechProcessingEvent,
      onError: (error) => _handleComponentError('SpeechProcessor', error),
    );

    // Subscribe to text processing events
    _textSubscription = _textProcessor.events.listen(
      _handleTextProcessingEvent,
      onError: (error) => _handleComponentError('TextProcessor', error),
    );

    // Subscribe to broadcast events
    _broadcastSubscription = _broadcastProcessor.events.listen(
      _handleBroadcastEvent,
      onError: (error) => _handleComponentError('BroadcastProcessor', error),
    );

    // Subscribe to speech result handling events
    _speechResultSubscription = _speechResultHandler.events.listen(
      _handleSpeechResultEvent,
      onError: (error) => _handleComponentError('SpeechResultHandler', error),
    );

    // Subscribe to text processing workflow events
    _textProcessingSubscription = _textProcessingHandler.events.listen(
      _handleTextProcessingWorkflowEvent,
      onError: (error) => _handleComponentError('TextProcessingHandler', error),
    );
  }

  /// Handles speech processing events
  void _handleSpeechProcessingEvent(SpeechProcessingEvent event) {
    if (event is SpeechResultEvent) {
      // Forward speech results to the speech result handler
      _speechResultHandler.handleSpeechResult(
        event.result,
        isSessionActive: isActive,
      );
    } else if (event is SpeechErrorEvent) {
      _emitEvent(PipelineErrorEvent('SpeechProcessor', event.error, true));
    }
  }

  /// Handles text processing events
  void _handleTextProcessingEvent(TextProcessingEvent event) {
    // Text processing events are handled by the text processing workflow
    // This could emit pipeline-level events if needed
  }

  /// Handles broadcast events
  void _handleBroadcastEvent(BroadcastEvent event) {
    // Broadcast events could trigger pipeline-level notifications
    // For now, they're handled internally by the broadcast processor
  }

  /// Handles speech result events
  void _handleSpeechResultEvent(SpeechResultHandlingEvent event) {
    if (event is CompleteSentencesDetectedEvent) {
      // Trigger immediate processing of complete sentences
      _textProcessingHandler.processAccumulatedText(
        ProcessingTriggerReason.punctuation,
      );
    } else if (event is BufferForceFlushEvent) {
      // Trigger force processing
      _textProcessingHandler.processAccumulatedText(
        ProcessingTriggerReason.force,
      );
    }
  }

  /// Handles text processing workflow events
  void _handleTextProcessingWorkflowEvent(
    AccumulatedTextProcessingEvent event,
  ) {
    // These events provide feedback on the text processing workflow
    // Could be used for pipeline-level monitoring and statistics
  }

  /// Handles component errors
  void _handleComponentError(String componentName, dynamic error) {
    print('❌ [PipelineManager] Component error in $componentName: $error');

    _log.error(
      'Component error occurred',
      error: error,
      tag: 'ComponentError-$componentName',
    );

    // Determine if error is recoverable
    final recoverable = componentName != 'Initialization';

    _emitEvent(
      PipelineErrorEvent(
        componentName,
        Exception(error.toString()),
        recoverable,
      ),
    );
  }

  /// Calculates final session statistics
  PipelineSessionStats _calculateFinalStats() {
    final speechStats = _speechProcessor.getProcessingStats();
    final textStats = _textProcessor.getProcessingStats();
    final broadcastStats = _broadcastProcessor.getBroadcastStats();
    final bufferStats = _speechResultHandler.getBufferAnalytics();

    return PipelineSessionStats(
      sessionDuration: sessionDuration,
      totalSpeechResults: speechStats['totalResultsProcessed'] ?? 0,
      totalTextProcessed: textStats['totalProcessedTexts'] ?? 0,
      totalBroadcasts: broadcastStats['totalBroadcasts'] ?? 0,
      duplicatesSkipped: textStats['duplicatesSkipped'] ?? 0,
      speechStats: speechStats,
      textStats: textStats,
      broadcastStats: broadcastStats,
      bufferStats: bufferStats,
    );
  }

  /// Emergency stop for error conditions
  Future<void> _emergencyStop() async {
    print('🚨 [PipelineManager] Emergency stop initiated...');

    try {
      _textProcessingHandler.stopAutomaticProcessing();
      _speechProcessor.forceStop();
      _broadcastProcessor.forceReset();

      _setStatus(PipelineStatus.idle);
      print('✅ [PipelineManager] Emergency stop completed');
    } catch (e) {
      print('❌ [PipelineManager] Error during emergency stop: $e');
    }
  }

  /// Sets pipeline status and emits sync event
  void _setStatus(PipelineStatus newStatus) {
    if (_currentStatus != newStatus) {
      final previousStatus = _currentStatus;
      _currentStatus = newStatus;

      print(
        '🔄 [PipelineManager] Status changed: ${previousStatus.description} → ${newStatus.description}',
      );

      // Emit state synchronization event
      _emitStateSyncEvent();
    }
  }

  /// Emits state synchronization event
  void _emitStateSyncEvent() {
    final currentState = SpeakerSessionState(
      status: _mapPipelineStatusToHermesStatus(_currentStatus),
      targetLanguageCode: _currentTargetLanguage,
      audienceCount: _audienceHandler.audienceCount,
      languageDistribution: _audienceHandler.languageDistribution,
    );

    final componentStates = {
      'speechProcessor': _speechProcessor.getProcessingStats(),
      'textProcessor': _textProcessor.getProcessingStats(),
      'broadcastProcessor': _broadcastProcessor.getBroadcastStats(),
      'audienceHandler': _audienceHandler.getAudienceStats(),
    };

    _emitEvent(PipelineStateSyncEvent(currentState, componentStates));
  }

  /// Maps pipeline status to Hermes status
  HermesStatus _mapPipelineStatusToHermesStatus(PipelineStatus pipelineStatus) {
    switch (pipelineStatus) {
      case PipelineStatus.idle:
        return HermesStatus.idle;
      case PipelineStatus.initializing:
        return HermesStatus.buffering;
      case PipelineStatus.ready:
        return HermesStatus.idle;
      case PipelineStatus.active:
        return HermesStatus.listening;
      case PipelineStatus.paused:
        return HermesStatus.paused;
      case PipelineStatus.stopping:
        return HermesStatus.buffering;
      case PipelineStatus.error:
        return HermesStatus.error;
    }
  }

  /// Emits a pipeline management event
  void _emitEvent(PipelineManagementEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Gets comprehensive pipeline statistics
  Map<String, dynamic> getPipelineStats() {
    return {
      'currentStatus': _currentStatus.description,
      'isActive': isActive,
      'sessionDuration': sessionDuration.inSeconds,
      'targetLanguage': _currentTargetLanguage,
      'finalStats': _calculateFinalStats(),
    };
  }

  /// Disposes of all resources
  void dispose() {
    print('🗑️ [PipelineManager] Disposing pipeline manager...');

    // Cancel all subscriptions
    _speechSubscription?.cancel();
    _textSubscription?.cancel();
    _broadcastSubscription?.cancel();
    _speechResultSubscription?.cancel();
    _textProcessingSubscription?.cancel();

    // Close event controller
    if (!_eventController.isClosed) {
      _eventController.close();
    }

    print('✅ [PipelineManager] Pipeline manager disposed');
  }
}
