// lib/core/hermes_engine/usecases/buffer_management.dart

import 'dart:async';
import 'package:hermes/core/hermes_engine/config/hermes_config.dart';
import '../buffer/translation_buffer.dart';
import '../state/hermes_event.dart';
import '../utils/log.dart';

/// Use case to manage buffer thresholds and depletion timing.
class BufferManagementUseCase {
  final TranslationBuffer buffer;
  final HermesLogger logger;

  Timer? _depletionTimer;

  BufferManagementUseCase({required this.buffer, required this.logger});

  /// Checks if the buffer has reached the minimum segments to start playback.
  /// Returns [BufferReady] when threshold is met, otherwise null.
  BufferReady? checkBufferReady() {
    if (buffer.length >= kMinBufferSegments) {
      logger.info(
        'Buffer has ${buffer.length} segments, ready to play',
        tag: 'BufferManagement',
      );
      return const BufferReady();
    }
    return null;
  }

  /// Should be called when playback pops a segment.
  /// If buffer is now empty, starts a timer to emit [BufferEmpty] after timeout.
  /// Returns null immediately; when timer fires, your engine should handle the event.
  void handlePostPlayback() {
    if (buffer.isEmpty) {
      logger.info(
        'Buffer empty, starting depletion timer',
        tag: 'BufferManagement',
      );
      _depletionTimer?.cancel();
      _depletionTimer = Timer(
        const Duration(seconds: kBufferDepletionTimeoutSeconds),
        () {
          logger.info(
            'Buffer depletion timeout reached',
            tag: 'BufferManagement',
          );
          // Engine should listen for this and emit BufferEmpty
        },
      );
    }
  }

  /// Call to cancel any pending depletion timer (e.g., when new data arrives).
  void cancelDepletion() {
    if (_depletionTimer?.isActive ?? false) {
      _depletionTimer!.cancel();
      logger.info('Cancelled buffer depletion timer', tag: 'BufferManagement');
    }
  }

  /// Clean up resources
  void dispose() {
    _depletionTimer?.cancel();
  }
}
