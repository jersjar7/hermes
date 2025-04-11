// lib/features/translation/infrastructure/services/stt/stt_service.dart

import 'dart:async';
import 'dart:convert';
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
  bool _isInitializing = false; // Added to prevent concurrent initialization
  bool _isRecording = false;
  bool _isPaused = false;
  int _initializeAttempts = 0;
  DateTime? _startTime; // Track when operations begin for debugging

  StreamController<SpeechRecognitionResult>? _resultStreamController;
  StreamSubscription? _recognitionSubscription;

  /// Creates a new [SpeechToTextService]
  SpeechToTextService(this._logger, this._httpClient, this._recorder) {
    _logger.d("[STT_DEBUG] SpeechToTextService instantiated");
    _apiClient = SttApiClient(_httpClient, _logger);
    _audioHandler = AudioStreamHandler(_recorder, _logger);
    _startTime = DateTime.now();
  }

  /// Factory constructor for dependency injection
  static SpeechToTextService create(Logger logger) {
    logger.d("[STT_DEBUG] SpeechToTextService.create called");
    return SpeechToTextService(logger, http.Client(), AudioRecorder());
  }

  /// Current initialization state
  bool get isInitialized => _isInitialized;

  /// Whether initialization is in progress
  bool get isInitializing => _isInitializing;

  /// Initialize the service
  Future<bool> init() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d(
      "[STT_DEBUG] [+${elapsed}ms] init() called, _isInitialized=$_isInitialized, _isInitializing=$_isInitializing",
    );

    // Prevent concurrent initialization
    if (_isInitializing) {
      _logger.d(
        "[STT_DEBUG] [+${elapsed}ms] init() already in progress, waiting...",
      );

      // Wait for initialization to complete
      int attempts = 0;
      while (_isInitializing && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }

      _logger.d(
        "[STT_DEBUG] [+${elapsed}ms] Waited for initialization, _isInitialized=$_isInitialized",
      );
      return _isInitialized;
    }

    if (_isInitialized) return true;

    _isInitializing = true;
    _initializeAttempts++;

    try {
      _logger.d(
        "[STT_DEBUG] [+${elapsed}ms] Starting initialization (attempt #$_initializeAttempts)",
      );

      // Check API key
      final apiKey = Env.googleCloudApiKey;
      if (apiKey.isEmpty) {
        _logger.e('[STT_DEBUG] [+${elapsed}ms] Google Cloud API key is empty');
        _isInitializing = false;
        return false;
      } else {
        _logger.d(
          '[STT_DEBUG] [+${elapsed}ms] API key found: ${apiKey.substring(0, min(5, apiKey.length))}...(truncated)',
        );
      }

      // Check Firebase project ID
      final projectId = Env.firebaseProjectId;
      if (projectId.isEmpty) {
        _logger.e('[STT_DEBUG] [+${elapsed}ms] Firebase project ID is empty');
        _isInitializing = false;
        return false;
      } else {
        _logger.d('[STT_DEBUG] [+${elapsed}ms] Project ID found: $projectId');
      }

      // Check recorder availability - this is critical
      _logger.d('[STT_DEBUG] [+${elapsed}ms] Checking recorder support...');
      final isAvailable = await _recorder.isEncoderSupported(
        AudioEncoder.pcm16bits,
      );

      if (!isAvailable) {
        _logger.e(
          '[STT_DEBUG] [+${elapsed}ms] Recorder not available or encoder not supported',
        );
        _isInitializing = false;
        return false;
      } else {
        _logger.d(
          '[STT_DEBUG] [+${elapsed}ms] Audio recorder and encoder are available',
        );
      }

      // Check if .env file was loaded correctly
      _logger.d(
        '[STT_DEBUG] [+${elapsed}ms] Environment variables: API_BASE_URL=${Env.apiBaseUrl}',
      );

      // Initialize audio handler
      _logger.d('[STT_DEBUG] [+${elapsed}ms] Initializing audio handler');
      await _audioHandler.init();
      _logger.d('[STT_DEBUG] [+${elapsed}ms] Audio handler initialized');

      _isInitialized = true;
      _logger.d("[STT_DEBUG] [+${elapsed}ms] Service successfully initialized");
      return true;
    } catch (e, stacktrace) {
      _logger.e(
        'Failed to initialize STT service',
        error: e,
        stackTrace: stacktrace,
      );
      _logger.d("[STT_DEBUG] [+${elapsed}ms] Exception in init(): $e");
      _logger.d("[STT_DEBUG] [+${elapsed}ms] Stack trace: $stacktrace");
      return false;
    } finally {
      _isInitializing = false;
    }
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

    // Close existing stream if any
    _resultStreamController?.close();
    _recognitionSubscription?.cancel();

    // Create a new stream controller
    _logger.d(
      "[STT_DEBUG] [+${elapsed}ms] Creating new result stream controller",
    );
    _resultStreamController =
        StreamController<SpeechRecognitionResult>.broadcast(
          // Add lifecycle callbacks for better debugging
          onListen: () {
            _logger.d("[STT_DEBUG] First listener attached to result stream");
          },
          onCancel: () {
            _logger.d(
              "[STT_DEBUG] Last listener unsubscribed from result stream",
            );
          },
        );

    // Start the streaming process asynchronously
    _startStreamingProcess(sessionId, languageCode);

    // Return the stream immediately
    return _resultStreamController!.stream;
  }

  Future<void> _startStreamingProcess(
    String sessionId,
    String languageCode,
  ) async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    try {
      // Check permissions first
      _logger.d("[STT_DEBUG] [+${elapsed}ms] Checking microphone permission");
      final permissionStatus = await Permission.microphone.status;
      _logger.d(
        "[STT_DEBUG] [+${elapsed}ms] Microphone permission status: $permissionStatus",
      );

      if (permissionStatus != PermissionStatus.granted) {
        _logger.d("[STT_DEBUG] [+${elapsed}ms] Permission not granted");

        final requestResult = await Permission.microphone.request();
        _logger.d(
          "[STT_DEBUG] [+${elapsed}ms] Permission request result: $requestResult",
        );

        if (requestResult != PermissionStatus.granted) {
          throw MicrophonePermissionException(
            'Microphone permission is required for speech transcription.',
            permissionStatus: requestResult,
          );
        }
      }

      // After permission check and before initializing:
      _logger.d(
        "[STT_DEBUG] [+${elapsed}ms] Starting audio with following parameters:",
      );
      _logger.d("[STT_DEBUG] [+${elapsed}ms] Session ID: $sessionId");
      _logger.d("[STT_DEBUG] [+${elapsed}ms] Language code: $languageCode");
      _logger.d(
        "[STT_DEBUG] [+${elapsed}ms] STT API URL: https://speech.googleapis.com/v1p1beta1/speech:streamingRecognize",
      );

      // Initialize if needed
      if (!_isInitialized) {
        _logger.d(
          "[STT_DEBUG] [+${elapsed}ms] Not initialized, calling init()",
        );
        final initialized = await init();
        if (!initialized) {
          throw SttServiceInitializationException(
            'STT Service could not be initialized',
          );
        }
      }

      // Stop any existing recording
      if (_isRecording) {
        _logger.d(
          "[STT_DEBUG] [+${elapsed}ms] Already recording, stopping first",
        );
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
        "[STT_DEBUG] [+${elapsed}ms] STT Streaming Config: ${jsonEncode(config.toStreamingConfig())}",
      );

      // Start audio recording
      _isRecording = true;
      _isPaused = false;

      _logger.d("[STT_DEBUG] [+${elapsed}ms] Using real microphone input");

      // Start audio handler and get audio stream
      _logger.d("[STT_DEBUG] [+${elapsed}ms] Starting audio streaming");
      final success = await _audioHandler.startStreaming();

      if (!success) {
        throw AudioProcessingException('Failed to start audio streaming');
      }

      _logger.d(
        "[STT_DEBUG] [+${elapsed}ms] Audio streaming started successfully",
      );

      // Connect audio stream to STT API
      _logger.d(
        "[STT_DEBUG] [+${elapsed}ms] Connecting audio stream to STT API",
      );
      final sttStream = _apiClient.streamingRecognize(
        audioStream: _audioHandler.audioStream,
        config: config,
      );

      _logger.d("[STT_DEBUG] [+${elapsed}ms] STT API stream established");

      // Forward results to our stream controller
      _recognitionSubscription = sttStream.listen(
        (result) {
          final listenElapsed =
              _startTime != null
                  ? DateTime.now().difference(_startTime!).inMilliseconds
                  : 0;

          _logger.d(
            "[STT_DEBUG] [+${listenElapsed}ms] Received STT result: '${result.transcript}' (final: ${result.isFinal})",
          );

          if (!_resultStreamController!.isClosed) {
            _resultStreamController!.add(result);
          } else {
            _logger.d(
              "[STT_DEBUG] [+${listenElapsed}ms] Stream controller closed, discarding result",
            );
          }
        },
        onError: (error) {
          final listenElapsed =
              _startTime != null
                  ? DateTime.now().difference(_startTime!).inMilliseconds
                  : 0;

          _logger.e(
            '[STT_DEBUG] [+${listenElapsed}ms] Error in STT API stream',
            error: error,
          );

          if (!_resultStreamController!.isClosed) {
            _resultStreamController!.addError(error);
          }
        },
        onDone: () {
          final listenElapsed =
              _startTime != null
                  ? DateTime.now().difference(_startTime!).inMilliseconds
                  : 0;

          _logger.d('[STT_DEBUG] [+${listenElapsed}ms] STT API stream closed');

          // Don't close the controller here, as we might want to restart streaming
        },
      );

      _logger.d(
        "[STT_DEBUG] [+${elapsed}ms] Successfully set up transcription pipeline",
      );
    } catch (e, stacktrace) {
      final catchElapsed =
          _startTime != null
              ? DateTime.now().difference(_startTime!).inMilliseconds
              : 0;

      _logger.e(
        '[STT_DEBUG] [+${catchElapsed}ms] Error starting STT process',
        error: e,
        stackTrace: stacktrace,
      );

      if (!_resultStreamController!.isClosed) {
        if (e is MicrophonePermissionException) {
          _resultStreamController!.addError(e);
        } else {
          _resultStreamController!.addError(
            e is Exception ? e : Exception('Error starting STT process: $e'),
          );
        }
      }

      await stopStreaming();
    }
  }

  /// Stop streaming audio
  Future<void> stopStreaming() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d(
      "[STT_DEBUG] [+${elapsed}ms] stopStreaming called, _isRecording=$_isRecording",
    );

    if (!_isRecording) return;

    try {
      // Stop audio handling
      _logger.d("[STT_DEBUG] [+${elapsed}ms] Stopping audio handler");
      await _audioHandler.stopStreaming();
      _logger.d("[STT_DEBUG] [+${elapsed}ms] Audio handler stopped");

      // Cancel recognition subscription
      _logger.d(
        "[STT_DEBUG] [+${elapsed}ms] Cancelling recognition subscription",
      );
      await _recognitionSubscription?.cancel();
      _recognitionSubscription = null;
      _logger.d(
        "[STT_DEBUG] [+${elapsed}ms] Recognition subscription cancelled",
      );

      _isRecording = false;
      _isPaused = false;

      // Close the result stream controller
      _logger.d("[STT_DEBUG] [+${elapsed}ms] Closing result stream controller");
      await _resultStreamController?.close();
      _resultStreamController = null;

      _logger.d("[STT_DEBUG] [+${elapsed}ms] Streaming stopped successfully");
    } catch (e, stacktrace) {
      _logger.e(
        '[STT_DEBUG] [+${elapsed}ms] Error stopping STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
    }
  }

  /// Pause streaming audio
  Future<void> pauseStreaming() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d(
      "[STT_DEBUG] [+${elapsed}ms] pauseStreaming called, _isRecording=$_isRecording",
    );

    if (!_isRecording || _isPaused) return;

    try {
      _logger.d("[STT_DEBUG] [+${elapsed}ms] Pausing audio handler");
      await _audioHandler.pauseStreaming();
      _isPaused = true;
      _logger.d("[STT_DEBUG] [+${elapsed}ms] Audio streaming paused");
    } catch (e, stacktrace) {
      _logger.e(
        '[STT_DEBUG] [+${elapsed}ms] Error pausing STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
    }
  }

  /// Resume streaming audio
  Future<void> resumeStreaming() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d(
      "[STT_DEBUG] [+${elapsed}ms] resumeStreaming called, _isRecording=$_isRecording, _isPaused=$_isPaused",
    );

    if (!_isRecording || !_isPaused) return;

    try {
      _logger.d("[STT_DEBUG] [+${elapsed}ms] Resuming audio handler");
      await _audioHandler.resumeStreaming();
      _isPaused = false;
      _logger.d("[STT_DEBUG] [+${elapsed}ms] Audio streaming resumed");
    } catch (e, stacktrace) {
      _logger.e(
        '[STT_DEBUG] [+${elapsed}ms] Error resuming STT streaming',
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
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d(
      "[STT_DEBUG] [+${elapsed}ms] transcribeAudio called with languageCode=$languageCode",
    );

    try {
      // Initialize if needed
      if (!_isInitialized) {
        _logger.d(
          "[STT_DEBUG] [+${elapsed}ms] Not initialized, calling init()",
        );
        final initialized = await init();
        if (!initialized) {
          throw SttServiceInitializationException(
            'STT Service could not be initialized',
          );
        }
      }

      final config = SttConfig(
        languageCode: languageCode,
        enableAutomaticPunctuation: true,
        interimResults: false,
      );

      return await _apiClient.recognize(audioData: audioData, config: config);
    } catch (e, stacktrace) {
      _logger.e(
        '[STT_DEBUG] [+${elapsed}ms] Failed to transcribe audio',
        error: e,
        stackTrace: stacktrace,
      );
      rethrow;
    }
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

  // Helper function
  int min(int a, int b) => a < b ? a : b;
}
