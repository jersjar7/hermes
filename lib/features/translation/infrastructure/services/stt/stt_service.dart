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
      // Check recorder availability
      final isAvailable = await _recorder.isEncoderSupported(
        AudioEncoder.pcm16bits,
      );

      if (!isAvailable) {
        _logger.e('Recorder not available or encoder not supported');
        return false;
      }

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

      // Start audio recording
      _isRecording = true;

      // For development/debugging - comment out in production
      if (Env.isDevelopment) {
        _startMockTranscriptionResults();
        return;
      }

      // Start audio handler and get audio stream
      final success = await _audioHandler.startStreaming();

      if (!success) {
        throw AudioProcessingException('Failed to start audio streaming');
      }

      // Connect audio stream to STT API
      final sttStream = _apiClient.streamingRecognize(
        audioStream: _audioHandler.audioStream,
        config: config,
        projectId: Env.firebaseProjectId,
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

  /// For development/debugging - creates mock transcription results
  void _startMockTranscriptionResults() {
    _logger.d("[STT_DEBUG] Starting mock transcription results");

    // Send interim results every second
    Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (!_isRecording ||
          _resultStreamController == null ||
          _resultStreamController!.isClosed) {
        timer.cancel();
        return;
      }

      // Generate some demo text
      final text =
          "This is a test transcription. Tap stop speaking when you're done.";
      final now = DateTime.now().millisecondsSinceEpoch;
      final partialText = text.substring(0, (now % text.length).toInt());

      // Create and emit result
      final result = SpeechRecognitionResult(
        transcript: partialText,
        confidence: 0.9,
        isFinal: false,
        stability: 0.8,
      );

      _resultStreamController?.add(result);

      // Every 5 seconds, send a "final" result
      if (now % 5000 < 100) {
        final finalResult = SpeechRecognitionResult(
          transcript: "This is a test final transcription.${now % 10}",
          confidence: 0.95,
          isFinal: true,
          stability: 1.0,
        );
        _resultStreamController?.add(finalResult);
      }
    });
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

    if (!_isRecording) return;

    try {
      await _audioHandler.pauseStreaming();
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
    _logger.d("[STT_DEBUG] resumeStreaming called, _isRecording=$_isRecording");

    if (!_isRecording) return;

    try {
      await _audioHandler.resumeStreaming();
    } catch (e, stacktrace) {
      _logger.e(
        'Error resuming STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
    }
  }

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
