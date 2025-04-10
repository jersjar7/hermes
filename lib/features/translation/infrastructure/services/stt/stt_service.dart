// lib/features/translation/infrastructure/services/stt/stt_service.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

import 'package:hermes/config/env.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/audio_stream_handler.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/models/stt_config.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/models/stt_result.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_api_client.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_exceptions.dart';

/// Service to handle speech-to-text operations using Google Cloud STT
class SpeechToTextService {
  final Logger _logger;
  final http.Client _httpClient;
  final AudioRecorder _recorder;

  late final SttApiClient _apiClient;
  late final AudioStreamHandler _audioHandler;

  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isPaused = false;

  StreamController<SpeechRecognitionResult>? _resultStreamController;
  StreamSubscription? _recognitionSubscription;

  /// Creates a new [SpeechToTextService]
  SpeechToTextService(this._logger, this._httpClient, this._recorder) {
    _logger.d("[STT_DEBUG] SpeechToTextService instantiated");
    _apiClient = SttApiClient(_httpClient, _logger);
    _audioHandler = AudioStreamHandler(_recorder, _logger);
  }

  /// Factory constructor for dependency injection
  static SpeechToTextService create(Logger logger) {
    logger.d("[STT_DEBUG] SpeechToTextService.create called");
    return SpeechToTextService(logger, http.Client(), AudioRecorder());
  }

  /// Initialize the service
  Future<bool> init() async {
    _logger.d("[STT_DEBUG] init() called, _isInitialized=$_isInitialized");

    if (_isInitialized) return true;

    try {
      // Check API key
      final apiKey = Env.googleCloudApiKey;
      if (apiKey.isEmpty) {
        _logger.e('[STT_DEBUG] Google Cloud API key is empty');
        return false;
      } else {
        _logger.d(
          '[STT_DEBUG] API key found: ${apiKey.substring(0, 5)}...(truncated)',
        );
      }

      // Check Firebase project ID
      final projectId = Env.firebaseProjectId;
      if (projectId.isEmpty) {
        _logger.e('[STT_DEBUG] Firebase project ID is empty');
        return false;
      } else {
        _logger.d('[STT_DEBUG] Project ID found: $projectId');
      }

      // Check recorder availability
      final isAvailable = await _recorder.isEncoderSupported(
        AudioEncoder.pcm16bits,
      );

      if (!isAvailable) {
        _logger.e(
          '[STT_DEBUG] Recorder not available or encoder not supported',
        );
        return false;
      } else {
        _logger.d('[STT_DEBUG] Audio recorder and encoder are available');
      }

      // Check if .env file was loaded correctly
      _logger.d(
        '[STT_DEBUG] Environment variables: API_BASE_URL=${Env.apiBaseUrl}',
      );

      _isInitialized = true;
      _logger.d("[STT_DEBUG] Service successfully initialized");
      return true;
    } catch (e, stacktrace) {
      _logger.e(
        'Failed to initialize STT service',
        error: e,
        stackTrace: stacktrace,
      );
      _logger.d("[STT_DEBUG] Exception in init(): $e");
      _logger.d("[STT_DEBUG] Stack trace: $stacktrace");
      return false;
    }
  }

  /// Start streaming audio for transcription
  ///
  /// Returns a stream of transcription results
  Stream<SpeechRecognitionResult> startStreaming({
    required String sessionId,
    required String languageCode,
  }) {
    _logger.d(
      "[STT_DEBUG] startStreaming called with languageCode=$languageCode",
    );

    // Close existing stream if any
    _resultStreamController?.close();
    _recognitionSubscription?.cancel();

    // Create a new stream controller
    _resultStreamController =
        StreamController<SpeechRecognitionResult>.broadcast();

    // Start the streaming process asynchronously
    _startStreamingProcess(sessionId, languageCode);

    // Return the stream immediately
    return _resultStreamController!.stream;
  }

  Future<void> _startStreamingProcess(
    String sessionId,
    String languageCode,
  ) async {
    try {
      // Check permissions
      final permissionStatus = await Permission.microphone.status;
      _logger.d("[STT_DEBUG] Microphone permission status: $permissionStatus");

      if (permissionStatus != PermissionStatus.granted) {
        _logger.d("[STT_DEBUG] Permission not granted");

        final requestResult = await Permission.microphone.request();

        if (requestResult != PermissionStatus.granted) {
          throw MicrophonePermissionException(
            'Microphone permission is required for speech transcription.',
            permissionStatus: requestResult,
          );
        }
      }

      // After permission check and before initializing:
      _logger.d("[STT_DEBUG] Starting audio with following parameters:");
      _logger.d("[STT_DEBUG] Session ID: $sessionId");
      _logger.d("[STT_DEBUG] Language code: $languageCode");
      _logger.d(
        "[STT_DEBUG] STT API URL: https://speech.googleapis.com/v1p1beta1/speech:streamingRecognize",
      );

      // Initialize if needed
      if (!_isInitialized) {
        _logger.d("[STT_DEBUG] Not initialized, calling init()");
        final initialized = await init();
        if (!initialized) {
          throw SttServiceInitializationException(
            'STT Service could not be initialized',
          );
        }
      }

      // Stop any existing recording
      if (_isRecording) {
        _logger.d("[STT_DEBUG] Already recording, stopping first");
        await stopStreaming();
      }

      // Create STT config
      final config = SttConfig(
        languageCode: languageCode,
        enableAutomaticPunctuation: true,
        profanityFilter: false,
        interimResults: true,
        sampleRateHertz: 16000,
      );

      // After creating SttConfig:
      _logger.d(
        "[STT_DEBUG] STT Streaming Config: ${config.toStreamingConfig()}",
      );

      // Start audio recording
      _isRecording = true;
      _isPaused = false;

      _logger.d("[STT_DEBUG] Using real microphone input");

      // Start audio handler and get audio stream
      final success = await _audioHandler.startStreaming();

      if (!success) {
        throw AudioProcessingException('Failed to start audio streaming');
      }

      // Connect audio stream to STT API
      final sttStream = _apiClient.streamingRecognize(
        audioStream: _audioHandler.audioStream,
        config: config,
      );

      // Forward results to our stream controller
      _recognitionSubscription = sttStream.listen(
        (result) {
          _resultStreamController?.add(result);
        },
        onError: (error) {
          _logger.e('Error in STT API stream', error: error);
          _resultStreamController?.addError(error);
        },
        onDone: () {
          _logger.d('STT API stream closed');
        },
      );
    } catch (e, stacktrace) {
      _logger.e('Error starting STT process', error: e, stackTrace: stacktrace);

      if (e is MicrophonePermissionException) {
        _resultStreamController?.addError(e);
      } else {
        _resultStreamController?.addError(
          e is Exception ? e : Exception('Error starting STT process: $e'),
        );
      }

      await stopStreaming();
    }
  }

  /// Stop streaming audio
  Future<void> stopStreaming() async {
    _logger.d("[STT_DEBUG] stopStreaming called, _isRecording=$_isRecording");

    if (!_isRecording) return;

    try {
      // Stop audio handling
      await _audioHandler.stopStreaming();

      // Cancel recognition subscription
      await _recognitionSubscription?.cancel();
      _recognitionSubscription = null;

      _isRecording = false;
      _isPaused = false;

      // Close the result stream controller
      await _resultStreamController?.close();
      _resultStreamController = null;

      _logger.d("[STT_DEBUG] Streaming stopped successfully");
    } catch (e, stacktrace) {
      _logger.e(
        'Error stopping STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
    }
  }

  /// Pause streaming audio
  Future<void> pauseStreaming() async {
    _logger.d("[STT_DEBUG] pauseStreaming called, _isRecording=$_isRecording");

    if (!_isRecording || _isPaused) return;

    try {
      await _audioHandler.pauseStreaming();
      _isPaused = true;
      _logger.d("[STT_DEBUG] Audio streaming paused");
    } catch (e, stacktrace) {
      _logger.e(
        'Error pausing STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
    }
  }

  /// Resume streaming audio
  Future<void> resumeStreaming() async {
    _logger.d(
      "[STT_DEBUG] resumeStreaming called, _isRecording=$_isRecording, _isPaused=$_isPaused",
    );

    if (!_isRecording || !_isPaused) return;

    try {
      await _audioHandler.resumeStreaming();
      _isPaused = false;
      _logger.d("[STT_DEBUG] Audio streaming resumed");
    } catch (e, stacktrace) {
      _logger.e(
        'Error resuming STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
    }
  }

  /// Check if streaming is paused
  bool get isPaused => _isPaused;

  /// Transcribe a single audio file (batch mode)
  Future<List<SpeechRecognitionResult>> transcribeAudio({
    required Uint8List audioData,
    required String languageCode,
  }) async {
    _logger.d(
      "[STT_DEBUG] transcribeAudio called with languageCode=$languageCode",
    );

    try {
      final config = SttConfig(
        languageCode: languageCode,
        enableAutomaticPunctuation: true,
        interimResults: false,
      );

      return await _apiClient.recognize(audioData: audioData, config: config);
    } catch (e, stacktrace) {
      _logger.e('Failed to transcribe audio', error: e, stackTrace: stacktrace);
      rethrow;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    _logger.d("[STT_DEBUG] dispose called");
    await stopStreaming();
    await _audioHandler.dispose();
    _isInitialized = false;
    _logger.d("[STT_DEBUG] Resources disposed");
  }
}
