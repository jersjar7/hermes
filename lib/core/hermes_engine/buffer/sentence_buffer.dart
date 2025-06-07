// lib/core/hermes_engine/buffer/sentence_buffer.dart

/// FIXED: Buffers speech transcripts across STT restarts for 15-second timer processing
/// Handles iOS Speech Recognition automatic restarts without losing context
class SentenceBuffer {
  // Buffer state
  String _pendingText = '';
  String _lastProcessedText = '';
  DateTime _lastPunctuationTime = DateTime.now();
  DateTime _bufferStartTime = DateTime.now();

  // 🆕 NEW: Cross-restart accumulation state
  String _accumulatedText = '';
  String _lastFlushedText =
      ''; // 🆕 NEW: Track what we last flushed to avoid duplication

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

  /// 🎯 FIXED: Cross-restart accumulation for 15-second timer processing
  /// Handles iOS Speech Recognition restarts without losing accumulated text
  String? getCompleteSentencesForProcessing(String latestPartial) {
    final cleanPartial = latestPartial.trim();

    // Skip if no new content
    if (cleanPartial == _lastProcessedText || cleanPartial.isEmpty) {
      return null;
    }

    _lastProcessedText = cleanPartial;

    // 🆕 NEW: Check if this looks like a restart (completely different text)
    final isLikelyRestart = _isLikelySTTRestart(cleanPartial);

    if (isLikelyRestart) {
      print(
        '🔄 [SentenceBuffer] Detected STT restart, preserving accumulated text',
      );

      // 🎯 FIXED: Only preserve text if it wasn't just flushed
      if (_pendingText.trim().isNotEmpty &&
          _pendingText.trim() != _lastFlushedText.trim()) {
        _accumulatedText = _combineTexts(_accumulatedText, _pendingText.trim());
        print(
          '📚 [SentenceBuffer] Preserved text: "${_accumulatedText.substring(0, _accumulatedText.length.clamp(0, 50))}..." (${_accumulatedText.length} chars)',
        );
      } else if (_pendingText.trim() == _lastFlushedText.trim()) {
        print(
          '🚫 [SentenceBuffer] Skipping preservation - text was just flushed',
        );
      }

      // Reset pending text for new partial
      _pendingText = cleanPartial;
    } else {
      // Normal accumulation within the same STT session
      _pendingText = cleanPartial;
    }

    print(
      '📝 [SentenceBuffer] Updated buffer: "${_pendingText.substring(0, _pendingText.length.clamp(0, 50))}..." (${_pendingText.length} chars)',
    );
    if (_accumulatedText.isNotEmpty) {
      print(
        '📚 [SentenceBuffer] Total accumulated: "${_accumulatedText.substring(0, _accumulatedText.length.clamp(0, 50))}..." (${_accumulatedText.length} chars)',
      );
    }

    // 🎯 IMPORTANT: For 15-second timer logic, we DON'T immediately return complete sentences
    // We let the timer handle ALL processing to ensure consistent 15-second intervals
    return null;
  }

  /// 🆕 NEW: Detect if the partial looks like an STT restart
  bool _isLikelySTTRestart(String newPartial) {
    if (_pendingText.isEmpty) return false;

    // If new partial is much shorter and doesn't start with similar words, likely a restart
    if (newPartial.length < _pendingText.length * 0.3) {
      final newWords = newPartial.toLowerCase().split(' ').take(3).toList();
      final oldWords = _pendingText.toLowerCase().split(' ').take(3).toList();

      // Check if any of the first few words match
      final hasCommonWords = newWords.any((word) => oldWords.contains(word));

      if (!hasCommonWords) {
        return true;
      }
    }

    return false;
  }

  /// 🆕 NEW: Intelligently combine texts, avoiding duplication
  String _combineTexts(String accumulated, String newText) {
    if (accumulated.isEmpty) return newText;
    if (newText.isEmpty) return accumulated;

    // Add period if accumulated doesn't end with punctuation
    final needsPeriod =
        !_sentenceEnders.any((ender) => accumulated.endsWith(ender));
    final connector = needsPeriod ? '. ' : ' ';

    return accumulated + connector + newText;
  }

  /// 🎯 FIXED: Forces flush of ALL accumulated text (cross-restart + pending)
  String? flushPending({String reason = 'timer'}) {
    // Combine all accumulated text
    final allText = _getAllAccumulatedText();

    if (allText.trim().isEmpty) {
      print('🚫 [SentenceBuffer] No accumulated text to flush');
      return null;
    }

    // Only flush if meets minimum length
    if (allText.length < _minimumSentenceLength) {
      print(
        '🚫 [SentenceBuffer] Skipping flush - text too short (${allText.length} chars): "$allText"',
      );
      return null;
    }

    print(
      '🔄 [SentenceBuffer] Flushing ALL accumulated text (${allText.length} chars, reason: $reason): "${allText.substring(0, allText.length.clamp(0, 100))}..."',
    );
    print('🔄 [SentenceBuffer] FULL TEXT BEING FLUSHED: "$allText"');

    // 🎯 NEW: Track what we just flushed to prevent duplication
    _lastFlushedText = allText;

    // 🎯 CRITICAL: Reset all buffer state IMMEDIATELY after flush
    // This prevents already-processed text from being preserved in future restarts
    _resetBuffer();

    // Update analytics
    if (reason == 'force') {
      _forcedFlushCount++;
    } else {
      _punctuationBasedCount++; // Timer-based processing
    }
    _totalSentencesProcessed++;

    return allText;
  }

  /// 🆕 NEW: Get all accumulated text across restarts
  String _getAllAccumulatedText() {
    if (_accumulatedText.isEmpty && _pendingText.isEmpty) {
      return '';
    }

    if (_accumulatedText.isEmpty) {
      return _pendingText.trim();
    }

    if (_pendingText.isEmpty) {
      return _accumulatedText.trim();
    }

    return _combineTexts(_accumulatedText, _pendingText.trim());
  }

  /// Checks if we should force flush due to 30-second timeout without punctuation.
  bool shouldForceFlush() {
    final allText = _getAllAccumulatedText();
    if (allText.trim().isEmpty) {
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

  /// 🎯 FIXED: Resets buffer state but preserves flush tracking
  void _resetBuffer() {
    _pendingText = '';
    _lastProcessedText = '';
    _accumulatedText = ''; // Clear cross-restart accumulation
    _bufferStartTime = DateTime.now();
    _updatePunctuationTime(); // Reset punctuation timer
    // 🎯 NOTE: Don't reset _lastFlushedText - we need it for duplication detection
  }

  /// Completely clears all buffer state.
  void clear() {
    _resetBuffer();
    _lastFlushedText = ''; // Clear flush tracking on manual clear
    _lastPunctuationTime = DateTime.now();
    print(
      '🧹 [SentenceBuffer] Buffer cleared (including cross-restart accumulation and flush tracking)',
    );
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

  /// 🆕 NEW: Returns all accumulated text across restarts
  String get allAccumulatedText => _getAllAccumulatedText();

  bool get hasPendingText => _getAllAccumulatedText().trim().isNotEmpty;

  int get pendingTextLength => _getAllAccumulatedText().trim().length;

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
      'currentPendingLength': _pendingText.length,
      'accumulatedLength': _accumulatedText.length,
      'totalLength': pendingTextLength,
      'lastFlushedLength': _lastFlushedText.length,
      'timeSinceLastPunctuationSeconds': timeSinceLastPunctuation.inSeconds,
      'bufferAgeSeconds': bufferAge.inSeconds,
      'hasPendingText': hasPendingText,
    };
  }

  /// Returns a debug-friendly summary of current buffer state.
  String getDebugSummary() {
    return 'SentenceBuffer('
        'pending: ${_pendingText.length} chars, '
        'accumulated: ${_accumulatedText.length} chars, '
        'total: $pendingTextLength chars, '
        'processed: $_totalSentencesProcessed sentences, '
        'punctuation: ${timeSinceLastPunctuation.inSeconds}s ago, '
        'should_flush: ${shouldForceFlush()}'
        ')';
  }
}
