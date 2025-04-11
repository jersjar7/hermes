// lib/features/translation/infrastructure/services/stt/stt_batch_processor.dart

import 'dart:typed_data';

import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/models/stt_config.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/models/stt_result.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_api_client.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_exceptions.dart';

/// Handles batch processing of audio files for speech-to-text recognition
class SttBatchProcessor {
  final Logger _logger;
  final SttApiClient _apiClient;

  DateTime? _startTime;

  /// Creates a new [SttBatchProcessor]
  SttBatchProcessor(this._logger, this._apiClient) {
    _startTime = DateTime.now();
  }

  /// Process an audio file for transcription
  Future<List<SpeechRecognitionResult>> processAudio({
    required Uint8List audioData,
    required String languageCode,
    required bool isInitialized,
    required Future<bool> Function() initFunction,
  }) async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d(
      "[STT_BATCH] [+${elapsed}ms] processAudio called with languageCode=$languageCode",
    );

    try {
      // Initialize if needed
      if (!isInitialized) {
        _logger.d(
          "[STT_BATCH] [+${elapsed}ms] Not initialized, calling init()",
        );
        final initialized = await initFunction();
        if (!initialized) {
          throw SttServiceInitializationException(
            'STT Service could not be initialized',
          );
        }
      }

      // Configure the recognition parameters
      final config = SttConfig(
        languageCode: languageCode,
        enableAutomaticPunctuation: true,
        interimResults: false,
      );

      _logger.d(
        "[STT_BATCH] [+${elapsed}ms] Sending audio for batch processing",
      );

      // Log audio data stats (size)
      _logger.d(
        "[STT_BATCH] [+${elapsed}ms] Audio data size: ${audioData.length} bytes",
      );

      // Process the audio using the API client
      final results = await _apiClient.recognize(
        audioData: audioData,
        config: config,
      );

      _logger.d(
        "[STT_BATCH] [+${elapsed}ms] Received ${results.length} transcription results",
      );

      // Log the first result if available
      if (results.isNotEmpty) {
        _logger.d(
          "[STT_BATCH] [+${elapsed}ms] First result: ${results.first.transcript.substring(0, min(results.first.transcript.length, 30))}...",
        );
      }

      return results;
    } catch (e, stacktrace) {
      _logger.e(
        '[STT_BATCH] [+${elapsed}ms] Failed to process audio in batch mode',
        error: e,
        stackTrace: stacktrace,
      );
      rethrow;
    }
  }

  // Helper function
  int min(int a, int b) => a < b ? a : b;
}
