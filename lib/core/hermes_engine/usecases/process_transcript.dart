// lib/core/hermes_engine/usecases/process_transcript.dart

import 'package:hermes/core/hermes_engine/state/hermes_event.dart';
import 'package:hermes/core/services/translation/translation_service.dart';
import '../buffer/translation_buffer.dart';
import '../utils/log.dart';

/// Use case to process a finalized speech transcript:
/// - Translate the text
/// - Add result to buffer
/// - Emit TranslationCompleted event
class ProcessTranscriptUseCase {
  final ITranslationService translator;
  final TranslationBuffer buffer;
  final HermesLogger logger;

  ProcessTranscriptUseCase({
    required this.translator,
    required this.buffer,
    required this.logger,
  });

  /// Processes a [transcript] by translating it into [targetLanguage],
  /// adding the result to the buffer, and emitting TranslationCompleted.
  Future<TranslationCompleted> execute(
    String transcript,
    String targetLanguage,
  ) async {
    logger.info('Translating transcript', tag: 'ProcessTranscript');
    try {
      final result = await translator.translate(
        text: transcript,
        targetLanguageCode: targetLanguage,
      );
      final translated = result.translatedText;
      buffer.add(translated);
      logger.info('Added to buffer: $translated', tag: 'ProcessTranscript');
      return TranslationCompleted(translated);
    } catch (e, st) {
      logger.error(
        'Translation failed',
        error: e,
        stackTrace: st,
        tag: 'ProcessTranscript',
      );
      throw EngineErrorOccurred('Translation failed: $e');
    }
  }
}
