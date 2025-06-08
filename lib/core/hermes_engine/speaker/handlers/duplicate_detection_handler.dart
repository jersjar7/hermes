// lib/core/hermes_engine/speaker/handlers/duplicate_detection_handler.dart
// Text similarity and duplicate detection logic

import '../config/speaker_config.dart';
import '../state/speaker_session_state.dart';

/// Result of duplicate detection analysis
class DuplicateDetectionResult {
  /// The type of processing determined for the text
  final ProcessingType processingType;

  /// Whether the text should be processed (false if it's a duplicate)
  final bool shouldProcess;

  /// Text that should be removed from cache (for replacements)
  final String? textToRemove;

  /// The original text that was replaced (for logging/tracking)
  final String? replacedText;

  /// Similarity score with the most similar previous text (0.0 to 1.0)
  final double maxSimilarity;

  /// Reason for the decision (for debugging)
  final String reason;

  const DuplicateDetectionResult({
    required this.processingType,
    required this.shouldProcess,
    this.textToRemove,
    this.replacedText,
    this.maxSimilarity = 0.0,
    required this.reason,
  });

  /// Creates result for exact duplicate
  factory DuplicateDetectionResult.exactDuplicate(String text) {
    return DuplicateDetectionResult(
      processingType: ProcessingType.newContent,
      shouldProcess: false,
      reason:
          'Exact duplicate detected: "${text.substring(0, text.length.clamp(0, 30))}..."',
    );
  }

  /// Creates result for subset duplicate (current text contained in previous)
  factory DuplicateDetectionResult.subsetDuplicate(String text) {
    return DuplicateDetectionResult(
      processingType: ProcessingType.newContent,
      shouldProcess: false,
      reason:
          'Subset duplicate detected: "${text.substring(0, text.length.clamp(0, 30))}..."',
    );
  }

  /// Creates result for similar duplicate (high similarity, minor changes)
  factory DuplicateDetectionResult.similarDuplicate(
    String text,
    double similarity,
  ) {
    return DuplicateDetectionResult(
      processingType: ProcessingType.newContent,
      shouldProcess: false,
      maxSimilarity: similarity,
      reason:
          'Similar duplicate detected (${(similarity * 100).toInt()}% similar): "${text.substring(0, text.length.clamp(0, 30))}..."',
    );
  }

  /// Creates result for text expansion/replacement
  factory DuplicateDetectionResult.expansion({
    required String currentText,
    required String previousText,
    required double expansionRatio,
    required double similarity,
  }) {
    return DuplicateDetectionResult(
      processingType: ProcessingType.replacement,
      shouldProcess: true,
      textToRemove: previousText,
      replacedText: previousText,
      maxSimilarity: similarity,
      reason:
          'Text expansion detected: ${(expansionRatio * 100).toInt()}% longer',
    );
  }

  /// Creates result for new content
  factory DuplicateDetectionResult.newContent(String text) {
    return DuplicateDetectionResult(
      processingType: ProcessingType.newContent,
      shouldProcess: true,
      reason:
          'New content: "${text.substring(0, text.length.clamp(0, 30))}..."',
    );
  }
}

/// Handles text similarity calculation and duplicate detection
class DuplicateDetectionHandler {
  /// Cache of previously processed texts (normalized to lowercase)
  final Set<String> _processedTexts = <String>{};

  /// Analyzes text for duplicates and determines processing type
  ///
  /// This method implements a sophisticated duplicate detection algorithm that:
  /// 1. Checks for exact duplicates
  /// 2. Detects when current text is a subset of previous text
  /// 3. Identifies text expansions (when previous text is contained in current)
  /// 4. Calculates similarity scores for edge cases
  ///
  /// Returns [DuplicateDetectionResult] with processing decision
  DuplicateDetectionResult analyzeText(String text) {
    if (!SpeakerConfig.isTextLengthValid(text)) {
      return DuplicateDetectionResult.newContent(text);
    }

    final normalizedText = text.trim().toLowerCase();

    print('🔍 [DuplicateDetection] Analyzing: "${_previewText(text)}"');

    // Step 1: Check for exact duplicates
    if (_processedTexts.contains(normalizedText)) {
      print('🚫 [DuplicateDetection] Found exact duplicate');
      return DuplicateDetectionResult.exactDuplicate(text);
    }

    // Step 2: Advanced duplicate detection with similarity scoring
    String? textToRemove;

    double maxSimilarity = 0.0;
    ProcessingType processingType = ProcessingType.newContent;

    for (final processedText in _processedTexts) {
      final similarity = _calculateSimilarity(normalizedText, processedText);

      // Case A: Current text is completely contained in previous text (subset)
      if (processedText.contains(normalizedText) &&
          processedText.length > normalizedText.length) {
        print('🚫 [DuplicateDetection] Found subset duplicate');
        print('   Current:  "${_previewText(normalizedText)}"');
        print('   Previous: "${_previewText(processedText)}"');
        return DuplicateDetectionResult.subsetDuplicate(text);
      }

      // Case B: Previous text is contained in current text (expansion)
      if (normalizedText.contains(processedText) &&
          normalizedText.length > processedText.length) {
        final expansionRatio = normalizedText.length / processedText.length;

        // Ensure significant expansion
        if (SpeakerConfig.isValidExpansion(expansionRatio)) {
          print(
            '🔄 [DuplicateDetection] Found text expansion: ${(expansionRatio * 100).toInt()}% longer',
          );
          print('   Previous: "${_previewText(processedText)}"');
          print('   Current:  "${_previewText(normalizedText)}"');

          if (similarity > maxSimilarity) {
            maxSimilarity = similarity;
            textToRemove = processedText;
            processingType = ProcessingType.replacement;
          }
        }
      }
      // Case C: High similarity but different lengths (potential duplicate with minor changes)
      else if (similarity > SpeakerConfig.similarityThreshold &&
          similarity > maxSimilarity) {
        final lengthDiff = (normalizedText.length - processedText.length).abs();
        final avgLength = (normalizedText.length + processedText.length) / 2;
        final lengthDiffRatio = lengthDiff / avgLength;

        // If very similar but length difference is small, consider it a duplicate
        if (lengthDiffRatio < SpeakerConfig.maxLengthDifferenceRatio) {
          print(
            '🚫 [DuplicateDetection] Found similar duplicate: ${(similarity * 100).toInt()}% similar',
          );
          return DuplicateDetectionResult.similarDuplicate(text, similarity);
        }
      }
    }

    // Step 3: Return appropriate result based on analysis
    if (processingType == ProcessingType.replacement && textToRemove != null) {
      final expansionRatio = normalizedText.length / textToRemove.length;
      return DuplicateDetectionResult.expansion(
        currentText: normalizedText,
        previousText: textToRemove,
        expansionRatio: expansionRatio,
        similarity: maxSimilarity,
      );
    }

    // Step 4: New content
    print(
      '🆕 [DuplicateDetection] New content detected (${normalizedText.length} chars)',
    );
    return DuplicateDetectionResult.newContent(text);
  }

  /// Adds text to the processed cache and handles cache management
  void markTextAsProcessed(String text) {
    if (!SpeakerConfig.isTextLengthValid(text)) return;

    final normalizedText = text.trim().toLowerCase();
    _processedTexts.add(normalizedText);

    // Prevent memory bloat
    if (SpeakerConfig.shouldClearProcessedCache(_processedTexts.length)) {
      final oldSize = _processedTexts.length;
      _processedTexts.clear();
      print(
        '🧹 [DuplicateDetection] Cleared processed texts cache (was $oldSize items)',
      );
    }
  }

  /// Removes text from the processed cache (used for replacements)
  bool removeTextFromCache(String text) {
    if (!SpeakerConfig.isTextLengthValid(text)) return false;

    final normalizedText = text.trim().toLowerCase();
    final removed = _processedTexts.remove(normalizedText);

    if (removed) {
      print('✅ [DuplicateDetection] Removed previous text from cache');
    }

    return removed;
  }

  /// Calculates similarity between two texts using Jaccard similarity coefficient
  /// Returns value between 0.0 (completely different) and 1.0 (identical)
  double _calculateSimilarity(String text1, String text2) {
    if (text1 == text2) return 1.0;
    if (text1.isEmpty || text2.isEmpty) return 0.0;

    final words1 = text1.split(' ').where((w) => w.isNotEmpty).toSet();
    final words2 = text2.split(' ').where((w) => w.isNotEmpty).toSet();

    if (words1.isEmpty || words2.isEmpty) return 0.0;

    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;

    // Jaccard similarity coefficient
    final similarity = union > 0 ? intersection / union : 0.0;

    if (!SpeakerConfig.isValidSimilarityScore(similarity)) {
      print('⚠️ [DuplicateDetection] Invalid similarity score: $similarity');
      return 0.0;
    }

    return similarity;
  }

  /// Creates a preview of text for logging (truncated to configured length)
  String _previewText(String text) {
    if (text.length <= SpeakerConfig.debugSimilarityPreviewLength) {
      return text;
    }
    return '${text.substring(0, SpeakerConfig.debugSimilarityPreviewLength)}...';
  }

  /// Clears all processed texts from cache
  void clearCache() {
    final oldSize = _processedTexts.length;
    _processedTexts.clear();
    print(
      '🧹 [DuplicateDetection] Manually cleared cache (was $oldSize items)',
    );
  }

  /// Gets current cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'cacheSize': _processedTexts.length,
      'maxCacheSize': SpeakerConfig.maxProcessedTextsCache,
      'cacheUtilization':
          _processedTexts.length / SpeakerConfig.maxProcessedTextsCache,
      'shouldClear': SpeakerConfig.shouldClearProcessedCache(
        _processedTexts.length,
      ),
    };
  }

  /// Checks if a specific text exists in the cache
  bool isTextInCache(String text) {
    if (!SpeakerConfig.isTextLengthValid(text)) return false;
    final normalizedText = text.trim().toLowerCase();
    return _processedTexts.contains(normalizedText);
  }

  /// Gets the number of texts currently in cache
  int get cacheSize => _processedTexts.length;

  /// Whether the cache is approaching capacity
  bool get isNearCapacity =>
      _processedTexts.length > (SpeakerConfig.maxProcessedTextsCache * 0.8);

  /// Disposes of resources and clears cache
  void dispose() {
    clearCache();
    print('🗑️ [DuplicateDetection] Handler disposed');
  }
}
