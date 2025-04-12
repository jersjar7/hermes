// lib/features/translation/infrastructure/repositories/TranscriptionAudioHandler.dart

import 'dart:typed_data';

import 'package:dartz/dartz.dart';
import 'package:injectable/injectable.dart';
import 'package:uuid/uuid.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/core/services/network_checker.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_service.dart';

/// Handles audio processing for transcription repository
class TranscriptionAudioHandler {
  final SpeechToTextService _sttService;
  final NetworkChecker _networkChecker;
  final Logger _logger;
  final _uuid = const Uuid();

  /// Creates a new [TranscriptionAudioHandler]
  TranscriptionAudioHandler(
    this._sttService,
    this._networkChecker,
    this._logger,
  );

  /// Transcribe audio file for a session
  Future<Either<Failure, Transcript>> transcribeAudio({
    required String sessionId,
    required Uint8List audioData,
    required String languageCode,
  }) async {
    _logger.d("[AUDIO_HANDLER] transcribeAudio called");

    if (audioData.isEmpty) {
      _logger.d("[AUDIO_HANDLER] Audio data is empty");
      return const Left(
        SpeechRecognitionFailure(message: 'Audio data is empty'),
      );
    }

    try {
      _logger.d("[AUDIO_HANDLER] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        _logger.d("[AUDIO_HANDLER] No network connection");
        return const Left(NetworkFailure());
      }

      _logger.d("[AUDIO_HANDLER] Ensuring STT service is initialized");
      final initialized = await _sttService.init();
      if (!initialized) {
        _logger.e("[AUDIO_HANDLER] Failed to initialize STT service");
        return Left(
          SpeechRecognitionFailure(
            message: 'Failed to initialize speech recognition service',
          ),
        );
      }

      // Attempt transcription with retry
      const maxRetries = 2;
      int retryCount = 0;
      List<SpeechRecognitionFailure> failures = [];

      while (retryCount <= maxRetries) {
        try {
          _logger.d(
            "[AUDIO_HANDLER] Calling STT service transcribeAudio (attempt ${retryCount + 1})",
          );
          final results = await _sttService.transcribeAudio(
            audioData: audioData,
            languageCode: languageCode,
          );

          if (results.isEmpty) {
            _logger.d("[AUDIO_HANDLER] No transcription results");
            failures.add(
              SpeechRecognitionFailure(message: 'No transcription results'),
            );
            retryCount++;
            // Add a delay before retry
            if (retryCount <= maxRetries) {
              await Future.delayed(Duration(milliseconds: 500 * retryCount));
            }
            continue;
          }

          // Get the best result (highest confidence)
          final bestResult = results.reduce(
            (curr, next) => curr.confidence > next.confidence ? curr : next,
          );
          _logger.d(
            "[AUDIO_HANDLER] Best result: transcript='${bestResult.transcript}', confidence=${bestResult.confidence}",
          );

          // Create transcript entity
          final transcript = Transcript(
            id: _uuid.v4(),
            sessionId: sessionId,
            text: bestResult.transcript,
            language: languageCode,
            timestamp: DateTime.now(),
            isFinal: true,
          );

          _logger.d("[AUDIO_HANDLER] Transcription successful");
          return Right(transcript);
        } catch (e) {
          _logger.d(
            "[AUDIO_HANDLER] Error in transcription attempt ${retryCount + 1}: $e",
          );
          failures.add(
            SpeechRecognitionFailure(
              message: 'Transcription attempt ${retryCount + 1} failed: $e',
            ),
          );
          retryCount++;

          // Add a delay before retry
          if (retryCount <= maxRetries) {
            await Future.delayed(Duration(milliseconds: 500 * retryCount));
          }
        }
      }

      // If we got here, all retries failed
      return Left(failures.last);
    } catch (e, stacktrace) {
      _logger.d("[AUDIO_HANDLER] Exception in transcribeAudio: $e");
      _logger.e('Failed to transcribe audio', error: e, stackTrace: stacktrace);
      return Left(SpeechRecognitionFailure(message: e.toString()));
    }
  }

  /// Initialize the audio handler
  Future<bool> initialize() async {
    _logger.d("[AUDIO_HANDLER] Initializing");
    try {
      return await _sttService.init();
    } catch (e) {
      _logger.e("[AUDIO_HANDLER] Error initializing", error: e);
      return false;
    }
  }
}
