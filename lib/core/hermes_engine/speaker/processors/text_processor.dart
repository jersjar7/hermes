// lib/core/hermes_engine/speaker/processors/text_processor.dart
// Grammar correction, translation, and duplicate detection pipeline

import 'dart:async';

import 'package:hermes/core/hermes_engine/utils/log.dart';
import 'package:hermes/core/services/grammar/language_tool_service.dart';
import 'package:hermes/core/services/translation/translation_service.dart';
import 'package:hermes/core/services/logger/logger_service.dart';

import '../config/speaker_config.dart';
import '../state/speaker_session_state.dart';
import '../handlers/duplicate_detection_handler.dart';

/// Text processing events
abstract class TextProcessingEvent {}

/// Text processing started
class TextProcessingStartedEvent extends TextProcessingEvent {
  final String originalText;
  final ProcessingTriggerReason reason;

  TextProcessingStartedEvent(this.originalText, this.reason);
}

/// Text processing stage changed
class TextProcessingStageChangedEvent extends TextProcessingEvent {
  final ProcessingStage stage;
  final String currentText;

  TextProcessingStageChangedEvent(this.stage, this.currentText);
}

/// Text processing completed successfully
class TextProcessingCompletedEvent extends TextProcessingEvent {
  final ProcessedTextResult result;

  TextProcessingCompletedEvent(this.result);
}

/// Text processing failed
class TextProcessingErrorEvent extends TextProcessingEvent {
  final String originalText;
  final ProcessingStage failedStage;
  final Exception error;

  TextProcessingErrorEvent(this.originalText, this.failedStage, this.error);
}

/// Text processing skipped (duplicate detected)
class TextProcessingSkippedEvent extends TextProcessingEvent {
  final String text;
  final String reason;

  TextProcessingSkippedEvent(this.text, this.reason);
}

/// Result of complete text processing pipeline
class ProcessedTextResult {
  /// Original input text
  final String originalText;

  /// Text after grammar correction
  final String correctedText;

  /// Final translated text
  final String translatedText;

  /// Target language code used for translation
  final String targetLanguageCode;

  /// Type of processing performed
  final ProcessingType processingType;

  /// Text that was replaced (if applicable)
  final String? replacedText;

  /// Reason why processing was triggered
  final ProcessingTriggerReason triggerReason;

  /// Time taken for grammar correction
  final Duration grammarLatency;

  /// Time taken for translation
  final Duration translationLatency;

  /// Total processing time
  final Duration totalLatency;

  /// Whether grammar correction was applied
  final bool grammarCorrectionApplied;

  const ProcessedTextResult({
    required this.originalText,
    required this.correctedText,
    required this.translatedText,
    required this.targetLanguageCode,
    required this.processingType,
    this.replacedText,
    required this.triggerReason,
    required this.grammarLatency,
    required this.translationLatency,
    required this.totalLatency,
    required this.grammarCorrectionApplied,
  });

  /// Whether this result represents a text replacement
  bool get isReplacement => processingType == ProcessingType.replacement;

  /// Whether grammar corrections were made
  bool get hadGrammarCorrections => correctedText != originalText;

  /// Total processing efficiency score (0.0 to 1.0)
  double get processingEfficiency {
    const maxAcceptableLatency = Duration(seconds: 3);
    if (totalLatency >= maxAcceptableLatency) return 0.0;
    return 1.0 -
        (totalLatency.inMilliseconds / maxAcceptableLatency.inMilliseconds);
  }
}

/// Handles the complete text processing pipeline
class TextProcessor {
  /// Grammar correction service
  final LanguageToolService _grammar;

  /// Translation service
  final ITranslationService _translation;

  /// Duplicate detection handler
  final DuplicateDetectionHandler _duplicateDetection;

  /// Logger for debugging and monitoring
  final HermesLogger _log;

  /// Stream controller for text processing events
  final StreamController<TextProcessingEvent> _eventController =
      StreamController<TextProcessingEvent>.broadcast();

  /// Current target language for translations
  String? _targetLanguageCode;

  /// Whether the grammar service is available
  bool _grammarServiceAvailable = false;

  /// Processing statistics
  int _totalProcessedTexts = 0;
  int _duplicatesSkipped = 0;
  int _grammarCorrections = 0;
  Duration _totalGrammarLatency = Duration.zero;
  Duration _totalTranslationLatency = Duration.zero;

  TextProcessor({
    required LanguageToolService grammar,
    required ITranslationService translation,
    required DuplicateDetectionHandler duplicateDetection,
    required ILoggerService logger,
  }) : _grammar = grammar,
       _translation = translation,
       _duplicateDetection = duplicateDetection,
       _log = HermesLogger(logger, 'TextProcessor');

  /// Stream of text processing events
  Stream<TextProcessingEvent> get events => _eventController.stream;

  /// Current target language code
  String? get targetLanguageCode => _targetLanguageCode;

  /// Whether grammar service is available for use
  bool get isGrammarServiceAvailable => _grammarServiceAvailable;

  /// Initializes the text processor with target language
  Future<void> initialize(String targetLanguageCode) async {
    print(
      '🔧 [TextProcessor] Initializing with target language: $targetLanguageCode',
    );

    if (!SpeakerConfig.isValidLanguageCode(targetLanguageCode)) {
      throw ArgumentError('Invalid language code: $targetLanguageCode');
    }

    _targetLanguageCode = targetLanguageCode;

    // Initialize grammar service
    _grammarServiceAvailable = await _grammar.initialize();

    if (!_grammarServiceAvailable) {
      print(
        '⚠️ [TextProcessor] Grammar service failed to initialize - continuing without grammar correction',
      );
      _log.info(
        'Grammar service unavailable, proceeding without corrections',
        tag: 'GrammarInit',
      );
    } else {
      print('✅ [TextProcessor] Grammar service initialized successfully');
      _log.info('Grammar service initialized successfully', tag: 'GrammarInit');
    }

    print('✅ [TextProcessor] Text processor initialized');
  }

  /// Processes text through the complete pipeline
  Future<ProcessedTextResult?> processText(
    String text,
    ProcessingTriggerReason reason,
  ) async {
    if (_targetLanguageCode == null) {
      throw StateError(
        'TextProcessor not initialized - call initialize() first',
      );
    }

    if (!SpeakerConfig.isTextLengthValid(text)) {
      print('🚫 [TextProcessor] Skipping empty or invalid text');
      return null;
    }

    final processingStart = DateTime.now();

    print(
      '🔄 [TextProcessor] Starting text processing: "${_previewText(text)}" (${reason.description})',
    );
    _emitEvent(TextProcessingStartedEvent(text, reason));

    try {
      // Step 1: Duplicate detection (unless skipping for stop operations)
      if (!reason.shouldSkipDuplicateDetection) {
        final duplicateResult = _duplicateDetection.analyzeText(text);

        if (!duplicateResult.shouldProcess) {
          print(
            '🚫 [TextProcessor] Skipping duplicate text: ${duplicateResult.reason}',
          );
          _duplicatesSkipped++;

          _emitEvent(TextProcessingSkippedEvent(text, duplicateResult.reason));
          return null;
        }

        // Handle text replacement
        if (duplicateResult.textToRemove != null) {
          _duplicateDetection.removeTextFromCache(
            duplicateResult.textToRemove!,
          );
          print('🔄 [TextProcessor] Processing text replacement');
        }
      }

      // Step 2: Grammar correction
      _emitStageChange(ProcessingStage.grammarCorrection, text);
      final grammarResult = await _performGrammarCorrection(text);

      // Step 3: Translation
      _emitStageChange(
        ProcessingStage.translation,
        grammarResult.correctedText,
      );
      final translationResult = await _performTranslation(
        grammarResult.correctedText,
      );

      // Step 4: Mark as processed
      _duplicateDetection.markTextAsProcessed(text);
      _totalProcessedTexts++;

      // Step 5: Create result
      final totalLatency = DateTime.now().difference(processingStart);
      final result = ProcessedTextResult(
        originalText: text,
        correctedText: grammarResult.correctedText,
        translatedText: translationResult.translatedText,
        targetLanguageCode: _targetLanguageCode!,
        processingType:
            reason.shouldSkipDuplicateDetection
                ? ProcessingType.newContent
                : _getProcessingType(text),
        triggerReason: reason,
        grammarLatency: grammarResult.latency,
        translationLatency: translationResult.latency,
        totalLatency: totalLatency,
        grammarCorrectionApplied: grammarResult.correctionApplied,
      );

      // Update statistics
      _totalGrammarLatency += grammarResult.latency;
      _totalTranslationLatency += translationResult.latency;
      if (grammarResult.correctionApplied) _grammarCorrections++;

      print(
        '✅ [TextProcessor] Processing completed in ${totalLatency.inMilliseconds}ms',
      );
      _emitEvent(TextProcessingCompletedEvent(result));

      _log.info(
        'Text processed successfully: "${_previewText(text)}" → "${_previewText(translationResult.translatedText)}" (${totalLatency.inMilliseconds}ms)',
        tag: 'ProcessComplete',
      );

      return result;
    } catch (e, stackTrace) {
      final totalLatency = DateTime.now().difference(processingStart);

      print(
        '❌ [TextProcessor] Processing failed after ${totalLatency.inMilliseconds}ms: $e',
      );

      _log.error(
        'Text processing failed',
        error: e,
        stackTrace: stackTrace,
        tag: 'ProcessError',
      );

      final failedStage = _getCurrentStageFromError(e);
      _emitEvent(
        TextProcessingErrorEvent(text, failedStage, Exception(e.toString())),
      );

      rethrow;
    }
  }

  /// Performs grammar correction with timeout and error handling
  Future<_GrammarResult> _performGrammarCorrection(String text) async {
    final grammarStart = DateTime.now();

    if (!_grammarServiceAvailable) {
      print(
        '⚠️ [TextProcessor] Grammar service unavailable, skipping correction',
      );
      return _GrammarResult(
        correctedText: text,
        latency: Duration.zero,
        correctionApplied: false,
      );
    }

    try {
      final correctedText = await _grammar
          .correctGrammar(text)
          .timeout(SpeakerConfig.grammarCorrectionTimeout);

      final latency = DateTime.now().difference(grammarStart);
      final correctionApplied = correctedText != text;

      if (correctionApplied) {
        print('✏️ [TextProcessor] Grammar corrections applied');
        print('   Original:  "${_previewText(text)}"');
        print('   Corrected: "${_previewText(correctedText)}"');
      }

      print(
        '📝 [TextProcessor] Grammar correction took ${latency.inMilliseconds}ms',
      );

      return _GrammarResult(
        correctedText: correctedText,
        latency: latency,
        correctionApplied: correctionApplied,
      );
    } catch (e) {
      final latency = DateTime.now().difference(grammarStart);
      print('❌ [TextProcessor] Grammar correction failed: $e');

      // Continue with original text if grammar correction fails
      return _GrammarResult(
        correctedText: text,
        latency: latency,
        correctionApplied: false,
      );
    }
  }

  /// Performs translation with timeout and error handling
  Future<_TranslationResult> _performTranslation(String text) async {
    final translationStart = DateTime.now();

    try {
      final result = await _translation
          .translate(text: text, targetLanguageCode: _targetLanguageCode!)
          .timeout(SpeakerConfig.translationTimeout);

      final latency = DateTime.now().difference(translationStart);

      print('🌍 [TextProcessor] Translation took ${latency.inMilliseconds}ms');
      print(
        '🌍 [TextProcessor] Translated: "${_previewText(result.translatedText)}"',
      );

      return _TranslationResult(
        translatedText: result.translatedText,
        latency: latency,
      );
    } catch (e) {
      print('❌ [TextProcessor] Translation failed: $e');
      throw Exception('Translation failed: $e');
    }
  }

  /// Determines processing type based on text analysis
  ProcessingType _getProcessingType(String text) {
    final duplicateResult = _duplicateDetection.analyzeText(text);
    return duplicateResult.processingType;
  }

  /// Gets current processing stage from error context
  ProcessingStage _getCurrentStageFromError(dynamic error) {
    final errorMsg = error.toString().toLowerCase();

    if (errorMsg.contains('grammar') || errorMsg.contains('correction')) {
      return ProcessingStage.grammarCorrection;
    } else if (errorMsg.contains('translation') ||
        errorMsg.contains('translate')) {
      return ProcessingStage.translation;
    } else {
      return ProcessingStage.speechRecognition; // Default fallback
    }
  }

  /// Emits stage change event
  void _emitStageChange(ProcessingStage stage, String currentText) {
    print('${stage.emoji} [TextProcessor] ${stage.description} stage');
    _emitEvent(TextProcessingStageChangedEvent(stage, currentText));
  }

  /// Emits a text processing event
  void _emitEvent(TextProcessingEvent event) {
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
  }

  /// Creates preview of text for logging
  String _previewText(String text) {
    if (text.length <= SpeakerConfig.debugTextPreviewLength) {
      return text;
    }
    return '${text.substring(0, SpeakerConfig.debugTextPreviewLength)}...';
  }

  /// Gets comprehensive processing statistics
  Map<String, dynamic> getProcessingStats() {
    final avgGrammarLatency =
        _totalProcessedTexts > 0
            ? _totalGrammarLatency.inMilliseconds / _totalProcessedTexts
            : 0.0;

    final avgTranslationLatency =
        _totalProcessedTexts > 0
            ? _totalTranslationLatency.inMilliseconds / _totalProcessedTexts
            : 0.0;

    return {
      'totalProcessedTexts': _totalProcessedTexts,
      'duplicatesSkipped': _duplicatesSkipped,
      'grammarCorrections': _grammarCorrections,
      'avgGrammarLatency': avgGrammarLatency,
      'avgTranslationLatency': avgTranslationLatency,
      'grammarServiceAvailable': _grammarServiceAvailable,
      'targetLanguageCode': _targetLanguageCode,
      'duplicateDetectionStats': _duplicateDetection.getCacheStats(),
    };
  }

  /// Resets processing statistics
  void resetStats() {
    print('🔄 [TextProcessor] Resetting processing statistics');

    _totalProcessedTexts = 0;
    _duplicatesSkipped = 0;
    _grammarCorrections = 0;
    _totalGrammarLatency = Duration.zero;
    _totalTranslationLatency = Duration.zero;
  }

  /// Clears duplicate detection cache
  void clearDuplicateCache() {
    _duplicateDetection.clearCache();
  }

  /// Disposes of resources
  void dispose() {
    print('🗑️ [TextProcessor] Disposing text processor...');

    _grammar.dispose();
    _duplicateDetection.dispose();

    if (!_eventController.isClosed) {
      _eventController.close();
    }

    print('✅ [TextProcessor] Text processor disposed');
  }
}

/// Internal grammar correction result
class _GrammarResult {
  final String correctedText;
  final Duration latency;
  final bool correctionApplied;

  const _GrammarResult({
    required this.correctedText,
    required this.latency,
    required this.correctionApplied,
  });
}

/// Internal translation result
class _TranslationResult {
  final String translatedText;
  final Duration latency;

  const _TranslationResult({
    required this.translatedText,
    required this.latency,
  });
}
