// lib/core/hermes_engine/buffer/buffer_analytics.dart

/// Analytics service for tracking buffer processing performance and metrics.
class BufferAnalytics {
  // Processing metrics
  int _totalProcessingCycles = 0;
  int _sentencesProcessed = 0;
  int _forcedFlushes = 0;
  int _punctuationBasedProcessing = 0;
  int _grammarCorrectionFailures = 0;
  int _translationFailures = 0;

  // Latency tracking
  final List<Duration> _grammarLatencies = [];
  final List<Duration> _translationLatencies = [];
  final List<Duration> _endToEndLatencies = [];

  // Text metrics
  final List<int> _textLengths = [];
  final List<int> _sentenceCounts = [];

  // Session tracking
  DateTime? _sessionStartTime;
  DateTime? _lastProcessingTime;

  /// Start tracking a new session
  void startSession() {
    _sessionStartTime = DateTime.now();
    _lastProcessingTime = DateTime.now();
    print('📊 [BufferAnalytics] Session started');
  }

  /// Log completion of a buffer processing cycle
  void logBufferProcessed({
    required int textLength,
    required int sentenceCount,
    required bool hadPunctuation,
    required bool wasForcedSend,
    required Duration grammarLatency,
    required Duration translationLatency,
    bool grammarFailed = false,
    bool translationFailed = false,
  }) {
    _totalProcessingCycles++;
    _sentencesProcessed += sentenceCount;
    _lastProcessingTime = DateTime.now();

    // Track processing type
    if (wasForcedSend) {
      _forcedFlushes++;
    } else if (hadPunctuation) {
      _punctuationBasedProcessing++;
    }

    // Track failures
    if (grammarFailed) _grammarCorrectionFailures++;
    if (translationFailed) _translationFailures++;

    // Track latencies
    _grammarLatencies.add(grammarLatency);
    _translationLatencies.add(translationLatency);

    final endToEndLatency = grammarLatency + translationLatency;
    _endToEndLatencies.add(endToEndLatency);

    // Track text metrics
    _textLengths.add(textLength);
    _sentenceCounts.add(sentenceCount);

    // Trim lists to keep memory usage reasonable
    _trimLists();

    print(
      '📊 [BufferAnalytics] Processed: $sentenceCount sentences, '
      '$textLength chars, E2E: ${endToEndLatency.inMilliseconds}ms',
    );
  }

  /// Generate comprehensive analytics report
  Map<String, dynamic> getAnalyticsReport() {
    final sessionDuration = _getSessionDuration();

    return {
      // Session info
      'sessionDurationSeconds': sessionDuration?.inSeconds ?? 0,
      'sessionStartTime': _sessionStartTime?.toIso8601String(),
      'lastProcessingTime': _lastProcessingTime?.toIso8601String(),

      // Processing metrics
      'totalProcessingCycles': _totalProcessingCycles,
      'sentencesProcessed': _sentencesProcessed,
      'averageSentencesPerCycle': _getAverageSentencesPerCycle(),

      // Processing type breakdown
      'punctuationBasedProcessing': _punctuationBasedProcessing,
      'forcedFlushes': _forcedFlushes,
      'punctuationRate': _getPunctuationRate(),
      'forcedFlushRate': _getForcedFlushRate(),

      // Failure rates
      'grammarCorrectionFailures': _grammarCorrectionFailures,
      'translationFailures': _translationFailures,
      'grammarFailureRate': _getGrammarFailureRate(),
      'translationFailureRate': _getTranslationFailureRate(),

      // Latency statistics
      'grammarLatency': _getLatencyStats(_grammarLatencies),
      'translationLatency': _getLatencyStats(_translationLatencies),
      'endToEndLatency': _getLatencyStats(_endToEndLatencies),

      // Text statistics
      'textLength': _getTextStats(_textLengths),
      'sentenceCount': _getTextStats(_sentenceCounts),

      // Performance indicators
      'averageProcessingRate': _getProcessingRate(),
      'isPerformingWell': _isPerformingWell(),
    };
  }

  /// Get simplified metrics for monitoring dashboards
  Map<String, dynamic> getSimpleMetrics() {
    return {
      'cyclesProcessed': _totalProcessingCycles,
      'sentencesProcessed': _sentencesProcessed,
      'avgEndToEndLatencyMs': _getAverageLatency(_endToEndLatencies),
      'grammarFailureRate': _getGrammarFailureRate(),
      'punctuationRate': _getPunctuationRate(),
      'isHealthy': _isPerformingWell(),
    };
  }

  // Private helper methods

  Duration? _getSessionDuration() {
    if (_sessionStartTime == null) return null;
    return DateTime.now().difference(_sessionStartTime!);
  }

  double _getAverageSentencesPerCycle() {
    if (_totalProcessingCycles == 0) return 0.0;
    return _sentencesProcessed / _totalProcessingCycles;
  }

  double _getPunctuationRate() {
    if (_totalProcessingCycles == 0) return 0.0;
    return _punctuationBasedProcessing / _totalProcessingCycles;
  }

  double _getForcedFlushRate() {
    if (_totalProcessingCycles == 0) return 0.0;
    return _forcedFlushes / _totalProcessingCycles;
  }

  double _getGrammarFailureRate() {
    if (_totalProcessingCycles == 0) return 0.0;
    return _grammarCorrectionFailures / _totalProcessingCycles;
  }

  double _getTranslationFailureRate() {
    if (_totalProcessingCycles == 0) return 0.0;
    return _translationFailures / _totalProcessingCycles;
  }

  Map<String, double> _getLatencyStats(List<Duration> latencies) {
    if (latencies.isEmpty) {
      return {'avg': 0.0, 'min': 0.0, 'max': 0.0, 'p95': 0.0};
    }

    final sortedMs =
        latencies.map((d) => d.inMilliseconds.toDouble()).toList()..sort();

    final p95Index = (sortedMs.length * 0.95).floor();

    return {
      'avg': sortedMs.reduce((a, b) => a + b) / sortedMs.length,
      'min': sortedMs.first,
      'max': sortedMs.last,
      'p95': sortedMs[p95Index.clamp(0, sortedMs.length - 1)],
    };
  }

  Map<String, double> _getTextStats(List<int> values) {
    if (values.isEmpty) {
      return {'avg': 0.0, 'min': 0.0, 'max': 0.0};
    }

    final sorted = List<int>.from(values)..sort();

    return {
      'avg': values.reduce((a, b) => a + b) / values.length,
      'min': sorted.first.toDouble(),
      'max': sorted.last.toDouble(),
    };
  }

  double _getAverageLatency(List<Duration> latencies) {
    if (latencies.isEmpty) return 0.0;
    final totalMs = latencies
        .map((d) => d.inMilliseconds)
        .reduce((a, b) => a + b);
    return totalMs / latencies.length;
  }

  double _getProcessingRate() {
    final duration = _getSessionDuration();
    if (duration == null || duration.inSeconds == 0) return 0.0;
    return _sentencesProcessed / duration.inSeconds;
  }

  bool _isPerformingWell() {
    if (_totalProcessingCycles < 3) return true; // Not enough data

    final avgEndToEnd = _getAverageLatency(_endToEndLatencies);
    final grammarFailureRate = _getGrammarFailureRate();
    final punctuationRate = _getPunctuationRate();

    return avgEndToEnd < 5000 && // Under 5 seconds end-to-end
        grammarFailureRate < 0.2 && // Under 20% grammar failures
        punctuationRate > 0.3; // At least 30% punctuation-based (good quality)
  }

  void _trimLists() {
    const maxSize = 200;

    if (_grammarLatencies.length > maxSize) {
      _grammarLatencies.removeRange(0, _grammarLatencies.length - maxSize);
    }
    if (_translationLatencies.length > maxSize) {
      _translationLatencies.removeRange(
        0,
        _translationLatencies.length - maxSize,
      );
    }
    if (_endToEndLatencies.length > maxSize) {
      _endToEndLatencies.removeRange(0, _endToEndLatencies.length - maxSize);
    }
    if (_textLengths.length > maxSize) {
      _textLengths.removeRange(0, _textLengths.length - maxSize);
    }
    if (_sentenceCounts.length > maxSize) {
      _sentenceCounts.removeRange(0, _sentenceCounts.length - maxSize);
    }
  }

  /// Reset all analytics data
  void reset() {
    _totalProcessingCycles = 0;
    _sentencesProcessed = 0;
    _forcedFlushes = 0;
    _punctuationBasedProcessing = 0;
    _grammarCorrectionFailures = 0;
    _translationFailures = 0;

    _grammarLatencies.clear();
    _translationLatencies.clear();
    _endToEndLatencies.clear();
    _textLengths.clear();
    _sentenceCounts.clear();

    _sessionStartTime = null;
    _lastProcessingTime = null;

    print('📊 [BufferAnalytics] Analytics reset');
  }

  /// Get debug summary
  String getDebugSummary() {
    final avgLatency = _getAverageLatency(_endToEndLatencies);
    return 'BufferAnalytics('
        'cycles: $_totalProcessingCycles, '
        'sentences: $_sentencesProcessed, '
        'avgLatency: ${avgLatency.toStringAsFixed(0)}ms, '
        'punctuationRate: ${(_getPunctuationRate() * 100).toStringAsFixed(1)}%, '
        'healthy: ${_isPerformingWell()}'
        ')';
  }
}
