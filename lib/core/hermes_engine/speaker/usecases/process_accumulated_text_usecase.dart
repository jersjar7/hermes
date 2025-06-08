// lib/core/hermes_engine/speaker/usecases/process_accumulated_text_usecase.dart
// Timer-based text processing workflow

import 'dart:async';

import 'package:hermes/core/hermes_engine/buffer/sentence_buffer.dart';
import 'package:hermes/core/hermes_engine/utils/log.dart';
import 'package:hermes/core/services/logger/logger_service.dart';

import '../config/speaker_config.dart';
import '../state/speaker_session_state.dart';
import '../processors/text_processor.dart';
import '../processors/broadcast_processor.dart';

/// Accumulated text processing events
abstract class AccumulatedTextProcessingEvent {}

/// Processing cycle started
class ProcessingCycleStartedEvent extends AccumulatedTextProcessingEvent {
  final ProcessingTriggerReason triggerReason;
  final String textToProcess;
  final DateTime timestamp;

  ProcessingCycleStartedEvent(
    this.triggerReason,
    this.textToProcess,
    this.timestamp,
  );
}

/// Processing cycle completed successfully
class ProcessingCycleCompletedEvent extends AccumulatedTextProcessingEvent {
  final ProcessedTextResult result;
  final BroadcastResult? broadcastResult;
  final Duration totalCycleTime;

  ProcessingCycleCompletedEvent(
    this.result,
    this.broadcastResult,
    this.totalCycleTime,
  );
}

/// Processing cycle failed
class ProcessingCycleFailedEvent extends AccumulatedTextProcessingEvent {
  final ProcessingTriggerReason triggerReason;
  final String originalText;
  final Exception error;
  final ProcessingStage? failedStage;
  final Duration attemptDuration;

  ProcessingCycleFailedEvent(
    this.triggerReason,
    this.originalText,
    this.error,
    this.failedStage,
    this.attemptDuration,
  );
}

/// No text available for processing
class NoTextAvailableEvent extends AccumulatedTextProcessingEvent {
  final ProcessingTriggerReason triggerReason;
  final String reason;

  NoTextAvailableEvent(this.triggerReason, this.reason);
}

/// Processing stage updated
class ProcessingStageUpdatedEvent extends AccumulatedTextProcessingEvent {
  final ProcessingStage stage;
  final String currentText;
  final Duration stageStartTime;

  ProcessingStageUpdatedEvent(
    this.stage,
    this.currentText,
    this.stageStartTime,
  );
}

/// Processing cycle statistics
class ProcessingCycleStats {
  final int totalCycles;
  final int successfulCycles;
  final int failedCycles;
  final int skippedCycles;
  final Duration totalProcessingTime;
  final Duration avgCycleTime;
  final Map<ProcessingTriggerReason, int> triggerReasonCounts;
  final Map<ProcessingStage, int> stageFailureCounts;

  const ProcessingCycleStats({
    required this.totalCycles,
    required this.successfulCycles,
    required this.failedCycles,
    required this.skippedCycles,
    required this.totalProcessingTime,
    required this.avgCycleTime,
    required this.triggerReasonCounts,
    required this.stageFailureCounts,
  });

  double get successRate =>
      totalCycles > 0 ? (successfulCycles / totalCycles) * 100.0 : 0.0;
  double get failureRate =>
      totalCycles > 0 ? (failedCycles / totalCycles) * 100.0 : 0.0;
  double get skipRate =>
      totalCycles > 0 ? (skippedCycles / totalCycles) * 100.0 : 0.0;
}

/// Use case for processing accumulated text through the complete pipeline
class ProcessAccumulatedTextUseCase {
  /// Text processor for grammar and translation
  final TextProcessor _textProcessor;

  /// Broadcast processor for sending translations
  final BroadcastProcessor _broadcastProcessor;

  /// Sentence buffer for text accumulation
  final SentenceBuffer _sentenceBuffer;

  /// Logger for debugging and monitoring
  final HermesLogger _log;

  /// Stream controller for processing events
  final StreamController<AccumulatedTextProcessingEvent> _eventController =
      StreamController<AccumulatedTextProcessingEvent>.broadcast();

  /// Processing statistics
  int _totalCycles = 0;
  int _successfulCycles = 0;
  int _failedCycles = 0;
  int _skippedCycles = 0;
  Duration _totalProcessingTime = Duration.zero;
  final Map<ProcessingTriggerReason, int> _triggerReasonCounts = {};
  final Map<ProcessingStage, int> _stageFailureCounts = {};

  /// Timer for automatic processing cycles
  Timer? _processingTimer;

  /// Whether automatic processing is enabled
  bool _automaticProcessingEnabled = false;

  ProcessAccumulatedTextUseCase({
    required TextProcessor textProcessor,
    required BroadcastProcessor broadcastProcessor,
    required SentenceBuffer sentenceBuffer,
    required ILoggerService logger,
  }) : _textProcessor = textProcessor,
       _broadcastProcessor = broadcastProcessor,
       _sentenceBuffer = sentenceBuffer,
       _log = HermesLogger(logger, 'AccumulatedTextProcessor');

  /// Stream of accumulated text processing events
  Stream<AccumulatedTextProcessingEvent> get events => _eventController.stream;

  /// Whether automatic processing is currently enabled
  bool get isAutomaticProcessingEnabled => _automaticProcessingEnabled;

  /// Current processing cycle statistics
  ProcessingCycleStats get stats => _calculateStats();

  /// Starts automatic processing with timer-based cycles
  void startAutomaticProcessing() {
    if (_automaticProcessingEnabled) {
      print(
        '⚠️ [AccumulatedTextProcessor] Automatic processing already enabled',
      );
      return;
    }

    print(
      '⏰ [AccumulatedTextProcessor] Starting automatic processing timer...',
    );
    _automaticProcessingEnabled = true;

    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(SpeakerConfig.processingInterval, (_) {
      processAccumulatedText(ProcessingTriggerReason.timer);
    });

    // Also check for force flush every few seconds
    Timer.periodic(SpeakerConfig.forceFlushCheckInterval, (_) {
      if (!_automaticProcessingEnabled) return;

      if (_sentenceBuffer.shouldForceFlush()) {
        processAccumulatedText(ProcessingTriggerReason.force);
      }
    });

    _log.info('Automatic text processing started', tag: 'AutoStart');
  }

  /// Stops automatic processing
  void stopAutomaticProcessing() {
    if (!_automaticProcessingEnabled) {
      print('⚠️ [AccumulatedTextProcessor] Automatic processing not enabled');
      return;
    }

    print('🛑 [AccumulatedTextProcessor] Stopping automatic processing...');
    _automaticProcessingEnabled = false;

    _processingTimer?.cancel();
    _processingTimer = null;

    _log.info('Automatic text processing stopped', tag: 'AutoStop');
  }

  /// Processes accumulated text through the complete pipeline
  Future<void> processAccumulatedText(ProcessingTriggerReason reason) async {
    final cycleStart = DateTime.now();
    _totalCycles++;
    _incrementTriggerReasonCount(reason);

    print(
      '🔄 [AccumulatedTextProcessor] Starting processing cycle (${reason.description})',
    );

    try {
      // Step 1: Get text to process from buffer
      final textToProcess = _getTextToProcess(reason);

      if (textToProcess == null || textToProcess.trim().isEmpty) {
        _handleNoTextAvailable(reason);
        return;
      }

      print(
        '📝 [AccumulatedTextProcessor] Processing text: "${_previewText(textToProcess)}"',
      );
      _emitEvent(
        ProcessingCycleStartedEvent(reason, textToProcess, cycleStart),
      );

      // Step 2: Process through text processor (grammar + translation)
      _emitStageUpdate(ProcessingStage.grammarCorrection, textToProcess);
      final processedResult = await _textProcessor.processText(
        textToProcess,
        reason,
      );

      if (processedResult == null) {
        _handleSkippedProcessing(
          reason,
          textToProcess,
          'Text processing returned null (likely duplicate)',
        );
        return;
      }

      // Step 3: Broadcast translation to audience
      _emitStageUpdate(
        ProcessingStage.broadcasting,
        processedResult.translatedText,
      );
      final broadcastResult = await _broadcastTranslation(processedResult);

      // Step 4: Complete successful cycle
      final totalCycleTime = DateTime.now().difference(cycleStart);
      _handleSuccessfulCycle(processedResult, broadcastResult, totalCycleTime);
    } catch (e, stackTrace) {
      final attemptDuration = DateTime.now().difference(cycleStart);
      await _handleFailedCycle(reason, e, stackTrace, attemptDuration);
    }
  }

  /// Gets text to process based on trigger reason
  String? _getTextToProcess(ProcessingTriggerReason reason) {
    switch (reason) {
      case ProcessingTriggerReason.timer:
      case ProcessingTriggerReason.force:
        return _sentenceBuffer.flushPending(reason: reason.name);

      case ProcessingTriggerReason.stop:
        // Process any remaining content when stopping
        return _sentenceBuffer.flushPending(reason: 'stop');

      case ProcessingTriggerReason.punctuation:
        // Get complete sentences only
        return _sentenceBuffer.getCompleteSentencesForProcessing('');

      case ProcessingTriggerReason.manual:
        return _sentenceBuffer.flushPending(reason: 'manual');
    }
  }

  /// Broadcasts translation through broadcast processor
  Future<BroadcastResult?> _broadcastTranslation(
    ProcessedTextResult processedResult,
  ) async {
    if (!_broadcastProcessor.canBroadcast) {
      print(
        '⚠️ [AccumulatedTextProcessor] Cannot broadcast - processor not ready',
      );
      return null;
    }

    try {
      return await _broadcastProcessor.broadcastTranslation(
        translatedText: processedResult.translatedText,
        targetLanguage: processedResult.targetLanguageCode,
      );
    } catch (e) {
      print('❌ [AccumulatedTextProcessor] Broadcast failed: $e');
      // Don't rethrow - processing was successful even if broadcast failed
      return null;
    }
  }

  /// Handles case when no text is available for processing
  void _handleNoTextAvailable(ProcessingTriggerReason reason) {
    _skippedCycles++;

    final reasonText =
        reason == ProcessingTriggerReason.timer
            ? 'No accumulated text available for timer-based processing'
            : 'Buffer empty for ${reason.description}';

    print('🚫 [AccumulatedTextProcessor] $reasonText');
    _emitEvent(NoTextAvailableEvent(reason, reasonText));
  }

  /// Handles skipped processing (e.g., duplicates)
  void _handleSkippedProcessing(
    ProcessingTriggerReason reason,
    String originalText,
    String skipReason,
  ) {
    _skippedCycles++;

    print('⏭️ [AccumulatedTextProcessor] Processing skipped: $skipReason');
    _emitEvent(NoTextAvailableEvent(reason, 'Processing skipped: $skipReason'));

    _log.info(
      'Processing cycle skipped: $skipReason for "${_previewText(originalText)}"',
      tag: 'ProcessingSkipped',
    );
  }

  /// Handles successful processing cycle
  void _handleSuccessfulCycle(
    ProcessedTextResult processedResult,
    BroadcastResult? broadcastResult,
    Duration totalCycleTime,
  ) {
    _successfulCycles++;
    _totalProcessingTime += totalCycleTime;

    print(
      '✅ [AccumulatedTextProcessor] Processing cycle completed in ${totalCycleTime.inMilliseconds}ms',
    );
    print('   Original: "${_previewText(processedResult.originalText)}"');
    print('   Translated: "${_previewText(processedResult.translatedText)}"');
    print('   Broadcasted: ${broadcastResult?.successful ?? false}');

    _emitEvent(
      ProcessingCycleCompletedEvent(
        processedResult,
        broadcastResult,
        totalCycleTime,
      ),
    );

    _log.info(
      'Processing cycle successful: "${_previewText(processedResult.originalText)}" → "${_previewText(processedResult.translatedText)}" (${totalCycleTime.inMilliseconds}ms)',
      tag: 'CycleSuccess',
    );
  }

  /// Handles failed processing cycle
  Future<void> _handleFailedCycle(
    ProcessingTriggerReason reason,
    dynamic error,
    StackTrace stackTrace,
    Duration attemptDuration,
  ) async {
    _failedCycles++;
    _totalProcessingTime += attemptDuration;

    final failedStage = _determineFailedStage(error);
    _incrementStageFailureCount(failedStage);

    print(
      '❌ [AccumulatedTextProcessor] Processing cycle failed after ${attemptDuration.inMilliseconds}ms: $error',
    );

    _emitEvent(
      ProcessingCycleFailedEvent(
        reason,
        'Unknown text', // We might not have the original text at this point
        Exception(error.toString()),
        failedStage,
        attemptDuration,
      ),
    );

    _log.error(
      'Processing cycle failed',
      error: error,
      stackTrace: stackTrace,
      tag: 'CycleFailed',
    );
  }

  /// Determines which stage failed based on error
  ProcessingStage _determineFailedStage(dynamic error) {
    final errorMsg = error.toString().toLowerCase();

    if (errorMsg.contains('grammar') || errorMsg.contains('correction')) {
      return ProcessingStage.grammarCorrection;
    } else if (errorMsg.contains('translation') ||
        errorMsg.contains('translate')) {
      return ProcessingStage.translation;
    } else if (errorMsg.contains('broadcast') || errorMsg.contains('socket')) {
      return ProcessingStage.broadcasting;
    } else {
      return ProcessingStage.stateUpdate; // Default fallback
    }
  }

  /// Emits stage update event
  void _emitStageUpdate(ProcessingStage stage, String currentText) {
    print(
      '${stage.emoji} [AccumulatedTextProcessor] ${stage.description} stage',
    );
    _emitEvent(ProcessingStageUpdatedEvent(stage, currentText, Duration.zero));
  }

  /// Increments trigger reason count
  void _incrementTriggerReasonCount(ProcessingTriggerReason reason) {
    _triggerReasonCounts[reason] = (_triggerReasonCounts[reason] ?? 0) + 1;
  }

  /// Increments stage failure count
  void _incrementStageFailureCount(ProcessingStage stage) {
    _stageFailureCounts[stage] = (_stageFailureCounts[stage] ?? 0) + 1;
  }

  /// Calculates current statistics
  ProcessingCycleStats _calculateStats() {
    final avgCycleTime =
        _successfulCycles > 0
            ? Duration(
              milliseconds:
                  _totalProcessingTime.inMilliseconds ~/ _successfulCycles,
            )
            : Duration.zero;

    return ProcessingCycleStats(
      totalCycles: _totalCycles,
      successfulCycles: _successfulCycles,
      failedCycles: _failedCycles,
      skippedCycles: _skippedCycles,
      totalProcessingTime: _totalProcessingTime,
      avgCycleTime: avgCycleTime,
      triggerReasonCounts: Map.from(_triggerReasonCounts),
      stageFailureCounts: Map.from(_stageFailureCounts),
    );
  }

  /// Creates preview of text for logging
  String _previewText(String text) {
    if (text.length <= SpeakerConfig.debugTextPreviewLength) {
      return text;
    }
    return '${text.substring(0, SpeakerConfig.debugTextPreviewLength)}...';
  }

  /// Emits a processing event
  void _emitEvent(AccumulatedTextProcessingEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Forces immediate processing of any accumulated text
  Future<void> forceProcessNow({String reason = 'force'}) async {
    print('🚨 [AccumulatedTextProcessor] Force processing triggered: $reason');
    await processAccumulatedText(ProcessingTriggerReason.force);
  }

  /// Resets all statistics
  void resetStats() {
    print('🔄 [AccumulatedTextProcessor] Resetting processing statistics');

    _totalCycles = 0;
    _successfulCycles = 0;
    _failedCycles = 0;
    _skippedCycles = 0;
    _totalProcessingTime = Duration.zero;
    _triggerReasonCounts.clear();
    _stageFailureCounts.clear();
  }

  /// Disposes of resources and stops processing
  void dispose() {
    print(
      '🗑️ [AccumulatedTextProcessor] Disposing accumulated text processor...',
    );

    stopAutomaticProcessing();

    if (!_eventController.isClosed) {
      _eventController.close();
    }

    print('✅ [AccumulatedTextProcessor] Accumulated text processor disposed');
  }
}
