// lib/features/translation/infrastructure/services/stt/stt_service.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:record/record.dart';

import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/audio_stream_handler.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/models/stt_result.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_api_client.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_initializer.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_streaming_manager.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_batch_processor.dart';

/// Service to handle speech-to-text operations using Google Cloud STT
@injectable
class SpeechToTextService {
  final Logger _logger;
  final http.Client _httpClient;
  final AudioRecorder _recorder;

  late final SttApiClient _apiClient;
  late final AudioStreamHandler _audioHandler;
  late final SttInitializer _initializer;
  late final SttStreamingManager _streamingManager;
  late final SttBatchProcessor _batchProcessor;

  bool _isInitialized = false;
  DateTime? _startTime; // Track when operations begin for debugging

  /// Creates a new [SpeechToTextService]
  SpeechToTextService(this._logger, this._httpClient, this._recorder) {
    _logger.d("[STT_DEBUG] SpeechToTextService instantiated");
    _apiClient = SttApiClient(_httpClient);
    _audioHandler = AudioStreamHandler(_recorder);
    _initializer = SttInitializer(_logger, _recorder);
    _streamingManager = SttStreamingManager(_logger, _apiClient, _audioHandler);
    _batchProcessor = SttBatchProcessor(_logger, _apiClient);
    _startTime = DateTime.now();
  }

  /// Factory constructor for dependency injection
  @factoryMethod
  static SpeechToTextService create(Logger logger) {
    logger.d("[STT_DEBUG] SpeechToTextService.create called");
    return SpeechToTextService(logger, http.Client(), AudioRecorder());
  }

  /// Current initialization state
  bool get isInitialized => _isInitialized;

  /// Whether initialization is in progress
  bool get isInitializing => _initializer.isInitializing;

  /// Initialize the service
  Future<bool> init() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d(
      "[STT_DEBUG] [+${elapsed}ms] init() called, _isInitialized=$_isInitialized, _isInitializing=${_initializer.isInitializing}",
    );

    if (_isInitialized) return true;

    final result = await _initializer.initialize(_audioHandler);
    _isInitialized = result;
    return result;
  }

  /// Start streaming audio for transcription
  ///
  /// Returns a stream of transcription results
  Stream<SpeechRecognitionResult> startStreaming({
    required String sessionId,
    required String languageCode,
  }) {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d(
      "[STT_DEBUG] [+${elapsed}ms] startStreaming called with languageCode=$languageCode",
    );

    return _streamingManager.startStreaming(
      sessionId: sessionId,
      languageCode: languageCode,
      isInitialized: _isInitialized,
      initFunction: init,
    );
  }

  /// Stop streaming audio
  Future<void> stopStreaming() async {
    return _streamingManager.stopStreaming();
  }

  /// Pause streaming audio
  Future<void> pauseStreaming() async {
    return _streamingManager.pauseStreaming();
  }

  /// Resume streaming audio
  Future<void> resumeStreaming() async {
    return _streamingManager.resumeStreaming();
  }

  /// Check if streaming is paused
  bool get isPaused => _streamingManager.isPaused;

  /// Transcribe a single audio file (batch mode)
  Future<List<SpeechRecognitionResult>> transcribeAudio({
    required Uint8List audioData,
    required String languageCode,
  }) async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d(
      "[STT_DEBUG] [+${elapsed}ms] transcribeAudio called with languageCode=$languageCode",
    );

    return _batchProcessor.processAudio(
      audioData: audioData,
      languageCode: languageCode,
      isInitialized: _isInitialized,
      initFunction: init,
    );
  }

  /// Dispose resources
  Future<void> dispose() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d("[STT_DEBUG] [+${elapsed}ms] dispose called");
    await stopStreaming();
    await _audioHandler.dispose();
    _isInitialized = false;
    _logger.d("[STT_DEBUG] [+${elapsed}ms] Resources disposed");
  }
}
