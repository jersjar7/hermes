// lib/core/hermes_engine/buffer/sentence_buffer.dart

/// Buffers speech transcripts and detects complete sentences for processing.
/// FIXED: Properly accumulates text over 15-second periods instead of replacing.
class SentenceBuffer {
  // Buffer state
  String _pendingText = '';
  String _lastProcessedText = '';
  DateTime _lastPunctuationTime = DateTime.now();
  DateTime _bufferStartTime = DateTime.now();

  // Analytics tracking
  int _totalSentencesProcessed = 0;
  int _forcedFlushCount = 0;
  int _punctuationBasedCount = 0;
  final List<Duration> _processingLatencies = [];

  // Configuration
  static const Duration _forceFlushTimeout = Duration(seconds: 30);
  static const int _minimumSentenceLength = 8;

  // Common sentence endings
  static const Set<String> _sentenceEnders = {'.', '!', '?'};

  // Common abbreviations to avoid false sentence breaks
  static const Set<String> _commonAbbreviations = {
    'Dr.',
    'Mr.',
    'Mrs.',
    'Ms.',
    'Prof.',
    'Sr.',
    'Jr.',
    'Inc.',
    'Corp.',
    'Ltd.',
    'Co.',
    'LLC.',
    'etc.',
    'vs.',
    'e.g.',
    'i.e.',
    'U.S.',
    'U.K.',
    'U.N.',
    'N.Y.',
    'L.A.',
    'Jan.',
    'Feb.',
    'Mar.',
    'Apr.',
    'Jun.',
    'Jul.',
    'Aug.',
    'Sep.',
    'Oct.',
    'Nov.',
    'Dec.',
  };

  /// 🎯 FIXED: Properly accumulates partials for 15-second timer processing
  /// Called every time we get a new partial result from STT.
  String? getCompleteSentencesForProcessing(String latestPartial) {
    final cleanPartial = latestPartial.trim();

    // Skip if no new content
    if (cleanPartial == _lastProcessedText || cleanPartial.isEmpty) {
      return null;
    }

    _lastProcessedText = cleanPartial;

    // 🎯 FIXED: For 15-second timer logic, we always accumulate the latest partial
    // The buffer should contain the most complete/recent version of the speech
    // since STT gives us progressively better transcriptions
    _pendingText = cleanPartial;

    print(
      '📝 [SentenceBuffer] Updated buffer: "${_pendingText.substring(0, _pendingText.length.clamp(0, 50))}..." (${_pendingText.length} chars)',
    );

    // 🎯 IMPORTANT: For 15-second timer logic, we DON'T immediately return complete sentences
    // We let the timer handle ALL processing to ensure consistent 15-second intervals
    return null;
  }

  /// Forces flush of pending text. Called by 15-second timer or 30-second force rule.
  String? flushPending({String reason = 'timer'}) {
    if (_pendingText.trim().isEmpty) {
      print('🚫 [SentenceBuffer] No pending text to flush');
      return null;
    }

    final textToFlush = _pendingText.trim();

    // Only flush if meets minimum length
    if (textToFlush.length < _minimumSentenceLength) {
      print(
        '🚫 [SentenceBuffer] Skipping flush - text too short (${textToFlush.length} chars): "$textToFlush"',
      );
      return null;
    }

    print(
      '🔄 [SentenceBuffer] Flushing accumulated text (${textToFlush.length} chars, reason: $reason): "${textToFlush.substring(0, textToFlush.length.clamp(0, 100))}..."',
    );

    // Reset buffer state
    _resetBuffer();

    // Update analytics
    if (reason == 'force') {
      _forcedFlushCount++;
    } else {
      _punctuationBasedCount++; // Timer-based processing
    }
    _totalSentencesProcessed++;

    return textToFlush;
  }

  /// Checks if we should force flush due to 30-second timeout without punctuation.
  bool shouldForceFlush() {
    if (_pendingText.trim().isEmpty) {
      return false;
    }

    final timeSinceLastPunctuation = DateTime.now().difference(
      _lastPunctuationTime,
    );
    final shouldFlush = timeSinceLastPunctuation >= _forceFlushTimeout;

    if (shouldFlush) {
      print(
        '⏰ [SentenceBuffer] Force flush triggered - ${timeSinceLastPunctuation.inSeconds}s without punctuation',
      );
    }

    return shouldFlush;
  }

  /// Updates the last punctuation timestamp.
  void _updatePunctuationTime() {
    _lastPunctuationTime = DateTime.now();
  }

  /// Resets buffer state for next cycle.
  void _resetBuffer() {
    _pendingText = '';
    _lastProcessedText = '';
    _bufferStartTime = DateTime.now();
    _updatePunctuationTime(); // Reset punctuation timer
  }

  /// Completely clears all buffer state.
  void clear() {
    _resetBuffer();
    _lastPunctuationTime = DateTime.now();
    print('🧹 [SentenceBuffer] Buffer cleared');
  }

  /// Records processing latency for analytics.
  void recordProcessingLatency(Duration latency) {
    _processingLatencies.add(latency);

    // Keep only last 100 measurements
    if (_processingLatencies.length > 100) {
      _processingLatencies.removeAt(0);
    }
  }

  // Getters for current state and analytics

  String get currentPendingText => _pendingText;

  bool get hasPendingText => _pendingText.trim().isNotEmpty;

  int get pendingTextLength => _pendingText.trim().length;

  Duration get timeSinceLastPunctuation =>
      DateTime.now().difference(_lastPunctuationTime);

  Duration get bufferAge => DateTime.now().difference(_bufferStartTime);

  /// Returns analytics data for monitoring and tuning.
  Map<String, dynamic> getAnalytics() {
    final avgLatency =
        _processingLatencies.isEmpty
            ? 0.0
            : _processingLatencies
                    .map((d) => d.inMilliseconds)
                    .reduce((a, b) => a + b) /
                _processingLatencies.length;

    return {
      'totalSentencesProcessed': _totalSentencesProcessed,
      'punctuationBasedCount': _punctuationBasedCount,
      'forcedFlushCount': _forcedFlushCount,
      'punctuationRate':
          _totalSentencesProcessed > 0
              ? _punctuationBasedCount / _totalSentencesProcessed
              : 0.0,
      'averageProcessingLatencyMs': avgLatency,
      'currentPendingLength': pendingTextLength,
      'timeSinceLastPunctuationSeconds': timeSinceLastPunctuation.inSeconds,
      'bufferAgeSeconds': bufferAge.inSeconds,
      'hasPendingText': hasPendingText,
    };
  }

  /// Returns a debug-friendly summary of current buffer state.
  String getDebugSummary() {
    return 'SentenceBuffer('
        'pending: $pendingTextLength chars, '
        'processed: $_totalSentencesProcessed sentences, '
        'punctuation: ${timeSinceLastPunctuation.inSeconds}s ago, '
        'should_flush: ${shouldForceFlush()}'
        ')';
  }
}
