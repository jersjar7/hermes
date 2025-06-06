// lib/core/services/grammar/language_tool_service.dart

import 'dart:async';
import 'package:language_tool/language_tool.dart';

/// Grammar correction service with timeout handling and selective filtering.
/// Focuses on punctuation and grammar corrections, avoiding spelling suggestions.
class LanguageToolService {
  static const Duration _defaultTimeout = Duration(seconds: 2);

  LanguageTool? _languageTool;
  bool _isInitialized = false;
  int _successCount = 0;
  int _failureCount = 0;
  int _timeoutCount = 0;
  final List<Duration> _correctionLatencies = [];

  /// Initialize the LanguageTool service.
  Future<bool> initialize() async {
    try {
      print('🔧 [LanguageTool] Initializing service...');

      _languageTool = LanguageTool();
      _isInitialized = true;

      print('✅ [LanguageTool] Initialized successfully');
      return true;
    } catch (e) {
      print('❌ [LanguageTool] Initialization failed: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Correct grammar with timeout. Returns original text if correction fails.
  Future<String> correctGrammar(String text, {Duration? timeout}) async {
    if (!_isInitialized || _languageTool == null) {
      print(
        '⚠️ [LanguageTool] Service not initialized, returning original text',
      );
      return text;
    }

    if (text.trim().isEmpty) {
      return text;
    }

    return await correctWithTimeout(text, timeout ?? _defaultTimeout);
  }

  /// Correct text with specified timeout, fallback to original on failure.
  Future<String> correctWithTimeout(String text, Duration timeout) async {
    final stopwatch = Stopwatch()..start();

    try {
      print(
        '🔍 [LanguageTool] Correcting: "${text.substring(0, text.length.clamp(0, 50))}..."',
      );

      // CORRECTED: check() returns Future<List<WritingMistake>>
      final List<WritingMistake> mistakes = await _languageTool!
          .check(text)
          .timeout(timeout);
      final correctedText = _applyCorrections(text, mistakes);

      stopwatch.stop();
      _recordSuccess(stopwatch.elapsed);

      if (correctedText != text) {
        print('✅ [LanguageTool] Applied ${mistakes.length} corrections');
        print(
          '   Original: "${text.substring(0, text.length.clamp(0, 40))}..."',
        );
        print(
          '   Corrected: "${correctedText.substring(0, correctedText.length.clamp(0, 40))}..."',
        );
      } else {
        print('✅ [LanguageTool] No corrections needed');
      }

      return correctedText;
    } on TimeoutException {
      stopwatch.stop();
      _timeoutCount++;
      print(
        '⏰ [LanguageTool] Timeout after ${timeout.inMilliseconds}ms, returning original',
      );
      return text;
    } catch (e) {
      stopwatch.stop();
      _failureCount++;
      print('❌ [LanguageTool] Correction failed: $e, returning original');
      return text;
    }
  }

  /// Apply filtered corrections to text.
  String _applyCorrections(String originalText, List<WritingMistake> mistakes) {
    if (mistakes.isEmpty) {
      return originalText;
    }

    // Filter mistakes to only include grammar and punctuation
    final filteredMistakes = _filterMistakes(mistakes);

    if (filteredMistakes.isEmpty) {
      print('🔍 [LanguageTool] All ${mistakes.length} mistakes filtered out');
      return originalText;
    }

    // Sort by offset in descending order to avoid index shifting
    filteredMistakes.sort((a, b) => b.offset.compareTo(a.offset));

    String correctedText = originalText;
    int appliedCorrections = 0;

    for (final mistake in filteredMistakes) {
      if (mistake.replacements.isNotEmpty) {
        final replacement = mistake.replacements.first;
        final start = mistake.offset;
        final end = mistake.offset + mistake.length;

        // Bounds checking
        if (start >= 0 && end <= correctedText.length && start < end) {
          correctedText =
              correctedText.substring(0, start) +
              replacement +
              correctedText.substring(end);
          appliedCorrections++;
        }
      }
    }

    print(
      '🔧 [LanguageTool] Applied $appliedCorrections/${filteredMistakes.length} filtered corrections',
    );
    return correctedText;
  }

  /// Filter mistakes to focus on grammar and punctuation, exclude spelling.
  List<WritingMistake> _filterMistakes(List<WritingMistake> mistakes) {
    return mistakes.where((mistake) {
      // CORRECTED: Use correct property names from WritingMistake
      final message = mistake.message.toLowerCase();
      final issueType = mistake.issueDescription.toLowerCase();

      // Include: Grammar and punctuation corrections
      if (_isGrammarCorrection(message, issueType)) {
        return true;
      }

      // Include: Capitalization fixes
      if (_isCapitalizationCorrection(message, issueType)) {
        return true;
      }

      // Include: Basic punctuation
      if (_isPunctuationCorrection(message, issueType)) {
        return true;
      }

      // Exclude: Spelling suggestions (too subjective for real-time translation)
      if (_isSpellingCorrection(message, issueType)) {
        return false;
      }

      // Default: Include if unclear (conservative approach)
      return true;
    }).toList();
  }

  bool _isGrammarCorrection(String message, String issueType) {
    const grammarKeywords = [
      'grammar',
      'verb',
      'tense',
      'agreement',
      'subject',
      'object',
      'pronoun',
      'article',
      'preposition',
      'conjunction',
    ];

    return grammarKeywords.any(
      (keyword) => message.contains(keyword) || issueType.contains(keyword),
    );
  }

  bool _isCapitalizationCorrection(String message, String issueType) {
    const capitalizationKeywords = [
      'capitalization',
      'uppercase',
      'lowercase',
      'capital',
    ];

    return capitalizationKeywords.any(
      (keyword) => message.contains(keyword) || issueType.contains(keyword),
    );
  }

  bool _isPunctuationCorrection(String message, String issueType) {
    const punctuationKeywords = [
      'punctuation',
      'comma',
      'period',
      'question',
      'exclamation',
      'apostrophe',
      'quotation',
      'semicolon',
      'colon',
    ];

    return punctuationKeywords.any(
      (keyword) => message.contains(keyword) || issueType.contains(keyword),
    );
  }

  bool _isSpellingCorrection(String message, String issueType) {
    const spellingKeywords = ['spelling', 'spellcheck', 'misspell', 'typo'];

    return spellingKeywords.any(
      (keyword) => message.contains(keyword) || issueType.contains(keyword),
    );
  }

  void _recordSuccess(Duration latency) {
    _successCount++;
    _correctionLatencies.add(latency);

    // Keep only last 100 measurements
    if (_correctionLatencies.length > 100) {
      _correctionLatencies.removeAt(0);
    }
  }

  /// Get service analytics and performance metrics.
  Map<String, dynamic> getAnalytics() {
    final totalAttempts = _successCount + _failureCount + _timeoutCount;
    final avgLatency =
        _correctionLatencies.isEmpty
            ? 0.0
            : _correctionLatencies
                    .map((d) => d.inMilliseconds)
                    .reduce((a, b) => a + b) /
                _correctionLatencies.length;

    return {
      'isInitialized': _isInitialized,
      'totalAttempts': totalAttempts,
      'successCount': _successCount,
      'failureCount': _failureCount,
      'timeoutCount': _timeoutCount,
      'successRate': totalAttempts > 0 ? _successCount / totalAttempts : 0.0,
      'timeoutRate': totalAttempts > 0 ? _timeoutCount / totalAttempts : 0.0,
      'averageLatencyMs': avgLatency,
    };
  }

  /// Dispose of resources.
  void dispose() {
    print('🗑️ [LanguageTool] Disposing service');
    _languageTool = null;
    _isInitialized = false;
  }
}
