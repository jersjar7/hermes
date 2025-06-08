// lib/core/hermes_engine/speaker/usecases/handle_speech_result_usecase.dart
// Real-time speech result processing workflow

import 'dart:async';

import 'package:hermes/core/hermes_engine/buffer/sentence_buffer.dart';
import 'package:hermes/core/hermes_engine/utils/log.dart';
import 'package:hermes/core/services/speech_to_text/speech_result.dart';
import 'package:hermes/core/services/logger/logger_service.dart';
import '../config/speaker_config.dart';
import '../state/speaker_session_state.dart';

/// Speech result handling events
abstract class SpeechResultHandlingEvent {}

/// Speech result received and is being processed
class SpeechResultReceivedEvent extends SpeechResultHandlingEvent {
  final SpeechResult result;
  final String bufferedContent;

  SpeechResultReceivedEvent(this.result, this.bufferedContent);
}

/// Complete sentences detected in speech result
class CompleteSentencesDetectedEvent extends SpeechResultHandlingEvent {
  final String completeSentences;
  final SpeechResult originalResult;

  CompleteSentencesDetectedEvent(this.completeSentences, this.originalResult);
}

/// Speech result added to buffer
class SpeechResultBufferedEvent extends SpeechResultHandlingEvent {
  final SpeechResult result;
  final BufferStatistics bufferStats;

  SpeechResultBufferedEvent(this.result, this.bufferStats);
}

/// Real-time transcript updated for UI
class TranscriptUpdatedEvent extends SpeechResultHandlingEvent {
  final String transcript;
  final bool isFinal;
  final double? confidence;
  final BufferStatistics bufferStats;

  TranscriptUpdatedEvent(
    this.transcript,
    this.isFinal,
    this.confidence,
    this.bufferStats,
  );
}

/// Buffer force flush triggered
class BufferForceFlushEvent extends SpeechResultHandlingEvent {
  final String reason;
  final String bufferedContent;
  final BufferStatistics bufferStats;

  BufferForceFlushEvent(this.reason, this.bufferedContent, this.bufferStats);
}

/// Use case for handling real-time speech recognition results
class HandleSpeechResultUseCase {
  /// Sentence buffer for accumulating speech
  final SentenceBuffer _sentenceBuffer;

  /// Logger for debugging and monitoring
  final HermesLogger _log;

  /// Stream controller for speech result handling events
  final StreamController<SpeechResultHandlingEvent> _eventController =
      StreamController<SpeechResultHandlingEvent>.broadcast();

  /// Statistics tracking
  int _totalResultsProcessed = 0;
  int _completeSentencesDetected = 0;
  int _forceFlushesTriggered = 0;
  DateTime? _lastResultTime;
  String? _lastTranscript;

  HandleSpeechResultUseCase({
    required SentenceBuffer sentenceBuffer,
    required ILoggerService logger,
  }) : _sentenceBuffer = sentenceBuffer,
       _log = HermesLogger(logger, 'SpeechResultHandler');

  /// Stream of speech result handling events
  Stream<SpeechResultHandlingEvent> get events => _eventController.stream;

  /// Current buffer statistics
  BufferStatistics get bufferStats => _getCurrentBufferStats();

  /// Whether buffer should be force flushed
  bool get shouldForceFlush => _sentenceBuffer.shouldForceFlush();

  /// Handles incoming speech recognition results
  Future<void> handleSpeechResult(
    SpeechResult result, {
    bool isSessionActive = true,
  }) async {
    if (!isSessionActive) {
      print('🚫 [SpeechResultHandler] Ignoring result - session inactive');
      return;
    }

    _totalResultsProcessed++;
    _lastResultTime = DateTime.now();
    _lastTranscript = result.transcript;

    print(
      '📝 [SpeechResultHandler] Processing speech result: "${_previewText(result.transcript)}" (final: ${result.isFinal})',
    );

    final currentBufferStats = bufferStats;
    _emitEvent(
      SpeechResultReceivedEvent(result, _sentenceBuffer.getCurrentContent()),
    );

    try {
      // Step 1: Always update UI with latest transcript for real-time feedback
      await _updateRealtimeTranscript(result, currentBufferStats);

      // Step 2: Process the speech result through sentence buffer
      await _processResultThroughBuffer(result);

      // Step 3: Check for complete sentences and handle immediately
      await _checkForCompleteSentences(result);

      // Step 4: Check if buffer needs force flushing
      await _checkForceFlush();

      _log.info(
        'Speech result processed: "${_previewText(result.transcript)}" (final: ${result.isFinal}, confidence: ${result.confidence?.toStringAsFixed(2) ?? 'N/A'})',
        tag: 'ResultProcessed',
      );
    } catch (e, stackTrace) {
      print('❌ [SpeechResultHandler] Error processing speech result: $e');

      _log.error(
        'Failed to process speech result',
        error: e,
        stackTrace: stackTrace,
        tag: 'ProcessingError',
      );

      // Continue processing despite error
    }
  }

  /// Updates real-time transcript for immediate UI feedback
  Future<void> _updateRealtimeTranscript(
    SpeechResult result,
    BufferStatistics stats,
  ) async {
    print('🔄 [SpeechResultHandler] Updating real-time transcript');

    _emitEvent(
      TranscriptUpdatedEvent(
        result.transcript,
        result.isFinal,
        result.confidence,
        stats,
      ),
    );
  }

  /// Processes speech result through the sentence buffer
  Future<void> _processResultThroughBuffer(SpeechResult result) async {
    // Update buffer with new transcript
    _sentenceBuffer.updateWithTranscript(result.transcript);

    final updatedStats = bufferStats;

    print(
      '📊 [SpeechResultHandler] Buffer updated - pending: ${updatedStats.pendingSentences}, chars: ${updatedStats.bufferCharacters}',
    );

    _emitEvent(SpeechResultBufferedEvent(result, updatedStats));
  }

  /// Checks for complete sentences and triggers immediate processing
  Future<void> _checkForCompleteSentences(SpeechResult result) async {
    final completeSentences = _sentenceBuffer.getCompleteSentencesForProcessing(
      result.transcript,
    );

    if (completeSentences != null && completeSentences.isNotEmpty) {
      _completeSentencesDetected++;

      print(
        '🎯 [SpeechResultHandler] Complete sentences detected: "${_previewText(completeSentences)}"',
      );

      _emitEvent(CompleteSentencesDetectedEvent(completeSentences, result));

      _log.info(
        'Complete sentences detected for immediate processing: "${_previewText(completeSentences)}"',
        tag: 'CompleteSentences',
      );
    }
  }

  /// Checks if buffer needs force flushing due to capacity
  Future<void> _checkForceFlush() async {
    if (!shouldForceFlush) return;

    _forceFlushesTriggered++;
    final currentStats = bufferStats;
    final reason = _determineForceFlushReason(currentStats);

    print('⚠️ [SpeechResultHandler] Buffer force flush triggered: $reason');

    final bufferedContent = _sentenceBuffer.getCurrentContent();
    _emitEvent(BufferForceFlushEvent(reason, bufferedContent, currentStats));

    _log.info(
      'Buffer force flush triggered: $reason (${currentStats.bufferCharacters} chars, ${currentStats.pendingSentences} sentences)',
      tag: 'ForceFlush',
    );
  }

  /// Determines the reason for force flushing
  String _determineForceFlushReason(BufferStatistics stats) {
    if (stats.bufferCharacters >= SpeakerConfig.maxBufferCharacters) {
      return 'Maximum buffer size reached (${stats.bufferCharacters}/${SpeakerConfig.maxBufferCharacters} chars)';
    }

    if (stats.pendingSentences >= SpeakerConfig.maxAccumulatedSentences) {
      return 'Maximum sentences accumulated (${stats.pendingSentences}/${SpeakerConfig.maxAccumulatedSentences} sentences)';
    }

    return 'Buffer capacity threshold exceeded';
  }

  /// Gets current buffer content for external processing
  String getCurrentBufferContent() {
    return _sentenceBuffer.getCurrentContent();
  }

  /// Flushes pending buffer content and returns it
  String? flushPendingContent({String reason = 'manual'}) {
    print('🔄 [SpeechResultHandler] Flushing pending content: $reason');

    final flushedContent = _sentenceBuffer.flushPending(reason: reason);

    if (flushedContent != null) {
      final currentStats = bufferStats;
      _emitEvent(BufferForceFlushEvent(reason, flushedContent, currentStats));

      _log.info(
        'Buffer manually flushed: $reason - "${_previewText(flushedContent)}"',
        tag: 'ManualFlush',
      );
    }

    return flushedContent;
  }

  /// Gets comprehensive buffer analytics
  Map<String, dynamic> getBufferAnalytics() {
    final stats = bufferStats;

    return {
      'pendingSentences': stats.pendingSentences,
      'bufferCharacters': stats.bufferCharacters,
      'bufferUtilization': stats.bufferUtilization,
      'isNearCapacity': stats.isNearCapacity,
      'shouldForceFlush': stats.shouldForceFlush,
      'timerFlushes': stats.timerFlushes,
      'forceFlushes': stats.forceFlushes,
      'punctuationFlushes': stats.punctuationFlushes,
      'totalBufferOperations': stats.totalBufferOperations,
    };
  }

  /// Gets speech result handling statistics
  Map<String, dynamic> getHandlingStats() {
    return {
      'totalResultsProcessed': _totalResultsProcessed,
      'completeSentencesDetected': _completeSentencesDetected,
      'forceFlushesTriggered': _forceFlushesTriggered,
      'lastResultTime': _lastResultTime?.toIso8601String(),
      'lastTranscript': _lastTranscript,
      'bufferAnalytics': getBufferAnalytics(),
    };
  }

  /// Gets current buffer statistics
  BufferStatistics _getCurrentBufferStats() {
    // This would ideally come from the sentence buffer, but we'll create it based on current state
    return BufferStatistics(
      pendingSentences: _sentenceBuffer.pendingSentenceCount,
      bufferCharacters: _sentenceBuffer.getCurrentContent().length,
      timerFlushes: 0, // These would be tracked by the buffer itself
      forceFlushes: _forceFlushesTriggered,
      punctuationFlushes: _completeSentencesDetected,
      totalBufferOperations: _totalResultsProcessed,
    );
  }

  /// Creates preview of text for logging
  String _previewText(String text) {
    if (text.length <= SpeakerConfig.debugTextPreviewLength) {
      return text;
    }
    return '${text.substring(0, SpeakerConfig.debugTextPreviewLength)}...';
  }

  /// Emits a speech result handling event
  void _emitEvent(SpeechResultHandlingEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Resets statistics and buffer state
  void reset() {
    print('🔄 [SpeechResultHandler] Resetting speech result handler');

    _sentenceBuffer.clear();
    _totalResultsProcessed = 0;
    _completeSentencesDetected = 0;
    _forceFlushesTriggered = 0;
    _lastResultTime = null;
    _lastTranscript = null;
  }

  /// Disposes of resources
  void dispose() {
    print('🗑️ [SpeechResultHandler] Disposing speech result handler...');

    if (!_eventController.isClosed) {
      _eventController.close();
    }

    print('✅ [SpeechResultHandler] Speech result handler disposed');
  }
}
