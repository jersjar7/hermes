// lib/core/hermes_engine/usecases/playback_control.dart

import 'dart:async';

import 'package:hermes/core/hermes_engine/state/hermes_event.dart';
import 'package:hermes/core/services/text_to_speech/text_to_speech_service.dart';

import '../buffer/translation_buffer.dart';
import '../utils/log.dart';

/// Use case to control playback of buffered segments via TTS.
/// - Pops next segment
/// - Calls TTS to speak it
/// - Emits [PlaybackFinished] after each segment
/// - If buffer empties, emits [BufferEmpty]
class PlaybackControlUseCase {
  final ITextToSpeechService ttsService;
  final TranslationBuffer buffer;
  final HermesLogger logger;

  PlaybackControlUseCase({
    required this.ttsService,
    required this.buffer,
    required this.logger,
  });

  /// Starts speaking through all buffered segments.
  /// Emits [PlaybackFinished] after each one, and [BufferEmpty] if none remain.
  Future<void> execute({
    required void Function(PlaybackFinished) onSegmentDone,
    required void Function(BufferEmpty) onBufferEmpty,
  }) async {
    // While there’s something to speak
    while (buffer.isNotEmpty) {
      final segment = buffer.pop()!;
      logger.info('Speaking segment: "$segment"', tag: 'PlaybackControl');
      await ttsService.speak(segment);
      logger.info('Finished speaking', tag: 'PlaybackControl');
      onSegmentDone(const PlaybackFinished());
      // Give a tiny delay if needed (optional)
      await Future.delayed(const Duration(milliseconds: 100));
    }

    // Buffer is empty now
    logger.info('Buffer is empty, playback completed', tag: 'PlaybackControl');
    onBufferEmpty(const BufferEmpty());
  }
}
