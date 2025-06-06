// lib/core/hermes_engine/buffer/sentence_buffer.dart

/// Buffers speech transcripts and detects complete sentences for processing.
/// Handles 15-second timer processing and 30-second force flush logic.
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

  /// Updates buffer with latest partial transcript and returns complete sentences if any.
  /// Called every time we get a new partial result from STT.
  String? getCompleteSentencesForProcessing(String latestPartial) {
    final cleanPartial = latestPartial.trim();

    // Skip if no new content
    if (cleanPartial == _lastProcessedText || cleanPartial.isEmpty) {
      return null;
    }

    _lastProcessedText = cleanPartial;
    _pendingText = cleanPartial;

    // Check for complete sentences with punctuation
    final completeSentences = _extractCompleteSentences(_pendingText);

    if (completeSentences.isNotEmpty) {
      _updatePunctuationTime();
      _punctuationBasedCount++;
      _totalSentencesProcessed++;

      print(
        '📝 [SentenceBuffer] Found ${completeSentences.length} complete sentences',
      );
      return completeSentences.join(' ');
    }

    return null;
  }

  /// Forces flush of pending text. Called by 15-second timer or 30-second force rule.
  String? flushPending({String reason = 'timer'}) {
    if (_pendingText.trim().isEmpty) {
      return null;
    }

    final textToFlush = _pendingText.trim();

    // Only flush if meets minimum length
    if (textToFlush.length < _minimumSentenceLength) {
      print(
        '🚫 [SentenceBuffer] Skipping flush - text too short (${textToFlush.length} chars)',
      );
      return null;
    }

    print(
      '🔄 [SentenceBuffer] Force flushing: "${textToFlush.substring(0, textToFlush.length.clamp(0, 50))}..." (reason: $reason)',
    );

    // Reset buffer state
    _resetBuffer();

    // Update analytics
    if (reason == 'force') {
      _forcedFlushCount++;
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

  /// Extracts complete sentences from text based on punctuation.
  List<String> _extractCompleteSentences(String text) {
    final sentences = <String>[];
    final buffer = StringBuffer();

    for (int i = 0; i < text.length; i++) {
      final char = text[i];
      buffer.write(char);

      if (_sentenceEnders.contains(char)) {
        final candidate = buffer.toString().trim();

        // Check if this is a real sentence ending
        if (_isCompleteSentence(candidate, text, i)) {
          sentences.add(candidate);
          buffer.clear();

          // Skip whitespace after sentence
          while (i + 1 < text.length && text[i + 1] == ' ') {
            i++;
          }
        }
      }
    }

    // Update pending text with remainder
    final remainder = buffer.toString().trim();
    _pendingText = remainder;

    return sentences;
  }

  /// Determines if a candidate string is actually a complete sentence.
  bool _isCompleteSentence(String candidate, String fullText, int position) {
    if (candidate.length < _minimumSentenceLength) {
      return false;
    }

    // Check for abbreviations
    if (_isLikelyAbbreviation(candidate)) {
      return false;
    }

    // Check for decimal numbers (e.g., "3.14")
    if (_isDecimalNumber(candidate)) {
      return false;
    }

    return true;
  }

  /// Checks if text ends with a common abbreviation.
  bool _isLikelyAbbreviation(String text) {
    for (final abbrev in _commonAbbreviations) {
      if (text.toLowerCase().endsWith(abbrev.toLowerCase())) {
        return true;
      }
    }
    return false;
  }

  /// Checks if text ends with a decimal number.
  bool _isDecimalNumber(String text) {
    final regex = RegExp(r'\d+\.\d*$');
    return regex.hasMatch(text);
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
