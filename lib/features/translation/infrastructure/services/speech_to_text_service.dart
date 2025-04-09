// lib/features/translation/infrastructure/services/speech_to_text_service.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:hermes/config/env.dart';
import 'package:hermes/core/utils/logger.dart';

/// Custom exception for microphone permission issues
class MicrophonePermissionException implements Exception {
  final String message;
  final PermissionStatus permissionStatus;

  MicrophonePermissionException(this.message, {required this.permissionStatus});

  @override
  String toString() => message;
}

/// Service to handle speech-to-text operations using Google Cloud STT
class SpeechToTextService {
  final Logger _logger;
  final http.Client _httpClient;
  final AudioRecorder _recorder;

  bool _isInitialized = false;
  bool _isRecording = false;
  StreamController<Uint8List>? _audioStreamController;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _amplitudeSubscription;

  final String _apiKey = Env.googleCloudApiKey;
  final String _apiBaseUrl = 'speech.googleapis.com';

  /// Creates a new [SpeechToTextService]
  SpeechToTextService(this._logger, this._httpClient, this._recorder) {
    print("[STT_DEBUG] SpeechToTextService instantiated");
  }

  /// Factory constructor for dependency injection
  @factoryMethod
  static SpeechToTextService create(Logger logger) {
    print("[STT_DEBUG] SpeechToTextService.create called");
    return SpeechToTextService(logger, http.Client(), AudioRecorder());
  }

  /// Initialize the service
  Future<bool> init() async {
    print("[STT_DEBUG] init() called, _isInitialized=$_isInitialized");

    if (_isInitialized) return true;

    try {
      // Check microphone permission - don't request yet, just check status
      final status = await Permission.microphone.status;
      print("[STT_DEBUG] Microphone permission status: $status");

      if (status != PermissionStatus.granted) {
        _logger.w('Microphone permission not granted: $status');
        print("[STT_DEBUG] Microphone permission not granted: $status");

        // Don't request permission here, just return false
        // The controller will handle requesting permissions
        return false;
      }

      _isInitialized = true;
      print("[STT_DEBUG] Service successfully initialized");
      return true;
    } catch (e, stacktrace) {
      _logger.e(
        'Failed to initialize STT service',
        error: e,
        stackTrace: stacktrace,
      );
      print("[STT_DEBUG] Exception in init(): $e");
      print("[STT_DEBUG] Stack trace: $stacktrace");
      return false;
    }
  }

  /// Start streaming audio for transcription
  ///
  /// Returns a stream of transcription results
  Stream<SpeechRecognitionResult> startStreaming({
    required String sessionId,
    required String languageCode,
  }) async* {
    print("[STT_DEBUG] startStreaming called with languageCode=$languageCode");

    // Check permissions first
    final permissionStatus = await Permission.microphone.status;
    print("[STT_DEBUG] Microphone permission status: $permissionStatus");

    // If permission is denied or permanently denied, throw a more specific exception
    if (permissionStatus != PermissionStatus.granted) {
      print("[STT_DEBUG] Permission not granted, throwing exception");
      throw MicrophonePermissionException(
        'Microphone permission is required for speech transcription.',
        permissionStatus: permissionStatus,
      );
    }

    print("[STT_DEBUG] Checking if initialized: $_isInitialized");
    if (!_isInitialized) {
      print("[STT_DEBUG] Not initialized, calling init()");
      final initialized = await init();
      if (!initialized) {
        print("[STT_DEBUG] Init failed");
        throw Exception('STT Service could not be initialized');
      }
    }

    print("[STT_DEBUG] Checking if recording: $_isRecording");
    if (_isRecording) {
      print("[STT_DEBUG] Already recording, stopping first");
      await stopStreaming();
    }

    try {
      print("[STT_DEBUG] Setting up audio stream controller");
      _audioStreamController = StreamController<Uint8List>.broadcast();
      _isRecording = true;

      // Configure recording
      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
      );
      print("[STT_DEBUG] Recording config created");

      // Check if recorder is available
      print("[STT_DEBUG] Checking if recorder is available");
      final isAvailable = await _recorder.isEncoderSupported(
        AudioEncoder.pcm16bits,
      );
      print("[STT_DEBUG] Recorder is available: $isAvailable");

      // Start recording with data stream
      print("[STT_DEBUG] Starting record stream");
      final audioStream = await _recorder.startStream(config);
      print("[STT_DEBUG] Record stream started");

      // Process the audio stream
      print("[STT_DEBUG] Setting up audio subscription");
      _audioSubscription = audioStream.listen(
        (data) {
          print("[STT_DEBUG] Audio data received: ${data.length} bytes");
          if (!_isRecording) return;
          _audioStreamController?.add(data);
        },
        onError: (error) {
          print("[STT_DEBUG] Audio stream error: $error");
        },
        onDone: () {
          print("[STT_DEBUG] Audio stream done");
        },
      );

      // Monitor amplitude for debugging
      print("[STT_DEBUG] Setting up amplitude subscription");
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
            // You can log amplitude or use it for UI feedback
            print("[STT_DEBUG] Amplitude: ${amp.current}, Max: ${amp.max}");
          });

      // Create a stream to send audio data to Google STT
      print("[STT_DEBUG] Creating STT stream with Google API");
      print(
        "[STT_DEBUG] API Key starts with: ${_apiKey.substring(0, min(5, _apiKey.length))}...",
      );
      print("[STT_DEBUG] Project ID: ${Env.firebaseProjectId}");

      final sttStream = _createSttStream(
        sessionId: sessionId,
        languageCode: languageCode,
        audioStream: _audioStreamController!.stream,
      );

      // Yield recognition results
      print("[STT_DEBUG] Yielding results from STT stream");
      await for (final result in sttStream) {
        print("[STT_DEBUG] Got result: ${result.transcript}");
        yield result;
      }
    } catch (e, stacktrace) {
      _logger.e('Error in STT streaming', error: e, stackTrace: stacktrace);
      print("[STT_DEBUG] Error in startStreaming: $e");
      print("[STT_DEBUG] Stack trace: $stacktrace");
      await stopStreaming();
      throw Exception('Error in STT streaming: $e');
    }
  }

  /// Stop streaming audio
  Future<void> stopStreaming() async {
    print("[STT_DEBUG] stopStreaming called, _isRecording=$_isRecording");

    if (!_isRecording) return;

    try {
      // Stop recording
      print("[STT_DEBUG] Stopping recorder");
      await _recorder.stop();
      print("[STT_DEBUG] Recorder stopped");

      // Cancel subscriptions
      print("[STT_DEBUG] Cancelling subscriptions");
      await _audioSubscription?.cancel();
      await _amplitudeSubscription?.cancel();
      await _audioStreamController?.close();
      print("[STT_DEBUG] Subscriptions cancelled");

      _isRecording = false;
      _audioSubscription = null;
      _amplitudeSubscription = null;
      _audioStreamController = null;
      print("[STT_DEBUG] Streaming stopped successfully");
    } catch (e, stacktrace) {
      _logger.e(
        'Error stopping STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
      print("[STT_DEBUG] Error in stopStreaming: $e");
      print("[STT_DEBUG] Stack trace: $stacktrace");
    }
  }

  /// Pause streaming audio
  Future<void> pauseStreaming() async {
    print("[STT_DEBUG] pauseStreaming called, _isRecording=$_isRecording");

    if (!_isRecording) return;

    try {
      print("[STT_DEBUG] Pausing recorder");
      await _recorder.pause();
      print("[STT_DEBUG] Recorder paused");
    } catch (e, stacktrace) {
      _logger.e(
        'Error pausing STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
      print("[STT_DEBUG] Error in pauseStreaming: $e");
      print("[STT_DEBUG] Stack trace: $stacktrace");
    }
  }

  /// Resume streaming audio
  Future<void> resumeStreaming() async {
    print("[STT_DEBUG] resumeStreaming called, _isRecording=$_isRecording");

    if (!_isRecording) return;

    try {
      print("[STT_DEBUG] Resuming recorder");
      await _recorder.resume();
      print("[STT_DEBUG] Recorder resumed");
    } catch (e, stacktrace) {
      _logger.e(
        'Error resuming STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
      print("[STT_DEBUG] Error in resumeStreaming: $e");
      print("[STT_DEBUG] Stack trace: $stacktrace");
    }
  }

  /// Create a stream to send audio data to Google STT
  Stream<SpeechRecognitionResult> _createSttStream({
    required String sessionId,
    required String languageCode,
    required Stream<Uint8List> audioStream,
  }) async* {
    print("[STT_DEBUG] _createSttStream called");

    // Setup Google Cloud Speech-to-Text V2 streaming API connection
    final uri = Uri.https(
      _apiBaseUrl,
      'v2/projects/${Env.firebaseProjectId}/locations/global:recognizeStream',
      {'key': _apiKey},
    );
    print("[STT_DEBUG] URI: $uri");

    final streamedRequest = http.StreamedRequest('POST', uri);
    streamedRequest.headers['Content-Type'] =
        'application/json+stream'; // Correct Content-Type for streaming
    print("[STT_DEBUG] Request headers: ${streamedRequest.headers}");

    // Start with config message
    final configJson = jsonEncode({
      'config': {
        'autoDecodingConfig': {},
        'languageCodes': [languageCode],
        'model': 'latest_short',
        'adaptation': {'phraseSets': [], 'customClasses': []},
        'recognition_features': {
          'enableAutomaticPunctuation': true,
          'profanityFilter': false,
          'enableSpokenPunctuation': true,
          'enableSpokenEmojis': true,
        },
        'transcription_format': {
          'transcriptNormalization': {
            'enableLowerCaseOutput': false,
            'enableTranscriptNormalization': true,
          },
        },
        'streaming_features': {'interimResults': true},
        'logging_options': {'enableDataLogging': true},
      },
      'recognitionOutputConfig': {
        'returnAlternatives': false,
        'maxAlternatives': 1,
      },
    });
    print("[STT_DEBUG] Config JSON created");

    // Send config first
    print("[STT_DEBUG] Sending config to API");
    streamedRequest.sink.add(utf8.encode('$configJson\n'));
    print("[STT_DEBUG] Config sent");

    // Process audio stream
    print("[STT_DEBUG] Setting up audio stream processing");
    final audioStreamController = StreamController<Uint8List>();
    audioStream.listen(
      (audioData) {
        // Convert audio data to base64
        print(
          "[STT_DEBUG] Converting audio data (${audioData.length} bytes) to base64",
        );
        final base64Audio = base64Encode(audioData);

        // Create audio content message
        final audioJson = jsonEncode({
          'audio': {'content': base64Audio},
        });

        // Send to STT API
        print("[STT_DEBUG] Sending audio data to API");
        streamedRequest.sink.add(utf8.encode('$audioJson\n'));
      },
      onDone: () {
        print(
          "[STT_DEBUG] Audio stream done, closing request sink and controller",
        );
        streamedRequest.sink.close();
        audioStreamController.close();
      },
      onError: (error) {
        print("[STT_DEBUG] Error in audio stream: $error");
        _logger.e('Error in audio stream', error: error);
        audioStreamController.addError(error);
      },
    );

    try {
      print("[STT_DEBUG] Creating HTTP client");
      final client = http.Client();
      print("[STT_DEBUG] Sending HTTP request");
      final streamedResponse = await client.send(streamedRequest);
      print(
        "[STT_DEBUG] HTTP response status code: ${streamedResponse.statusCode}",
      );

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        print("[STT_DEBUG] API Error response: $body");
        _logger.e('STT API Error: ${streamedResponse.statusCode}', error: body);
        throw Exception(
          'STT API Error: ${streamedResponse.statusCode} - $body',
        );
      }

      // Process streaming response (newline-delimited JSON)
      print("[STT_DEBUG] Processing API response stream");
      int lineCount = 0;
      await for (final chunk in streamedResponse.stream) {
        print("[STT_DEBUG] Received chunk of ${chunk.length} bytes");
        final lines = utf8.decode(chunk).split('\n');
        print("[STT_DEBUG] Chunk split into ${lines.length} lines");

        for (final line in lines) {
          lineCount++;
          if (line.trim().isEmpty) {
            print("[STT_DEBUG] Line $lineCount is empty, skipping");
            continue;
          }

          try {
            print(
              "[STT_DEBUG] Parsing line $lineCount: ${line.substring(0, min(50, line.length))}...",
            );
            final json = jsonDecode(line);
            final result = SpeechRecognitionResult.fromJson(json);
            print(
              "[STT_DEBUG] Parsed result: ${result.transcript}, isFinal=${result.isFinal}",
            );
            yield result;
          } catch (e, stacktrace) {
            print("[STT_DEBUG] Error parsing line $lineCount: $e");
            _logger.e(
              'Error parsing STT response line: $line',
              error: e,
              stackTrace: stacktrace,
            );
          }
        }
      }
      print("[STT_DEBUG] Response stream ended, closing client");
      client.close(); // Close the client when done
    } catch (e, stacktrace) {
      print("[STT_DEBUG] Error in STT API request: $e");
      print("[STT_DEBUG] Stack trace: $stacktrace");
      _logger.e('Error in STT API request', error: e, stackTrace: stacktrace);
      throw Exception('Error in STT API request: $e');
    }
  }

  /// Transcribe a single audio file
  Future<List<SpeechRecognitionResult>> transcribeAudio({
    required Uint8List audioData,
    required String languageCode,
  }) async {
    print("[STT_DEBUG] transcribeAudio called with languageCode=$languageCode");
    try {
      final uri = Uri.https(
        _apiBaseUrl,
        'v2/projects/${Env.firebaseProjectId}/locations/global:recognize',
        {'key': _apiKey},
      );
      print("[STT_DEBUG] URI: $uri");

      // Encode audio data as base64
      print("[STT_DEBUG] Encoding ${audioData.length} bytes as base64");
      final base64Audio = base64Encode(audioData);

      // Create request body
      final requestBody = jsonEncode({
        'config': {
          'autoDecodingConfig': {},
          'languageCodes': [languageCode],
          'model': 'latest_short',
          'adaptation': {'phraseSets': [], 'customClasses': []},
          'recognition_features': {
            'enableAutomaticPunctuation': true,
            'profanityFilter': false,
            'enableSpokenPunctuation': true,
            'enableSpokenEmojis': true,
          },
          'logging_options': {'enableDataLogging': true},
        },
        'audio': {'content': base64Audio},
      });
      print("[STT_DEBUG] Request body created");

      // Send request
      print("[STT_DEBUG] Sending HTTP request");
      final response = await _httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );
      print("[STT_DEBUG] HTTP response status code: ${response.statusCode}");

      if (response.statusCode != 200) {
        print("[STT_DEBUG] API Error response: ${response.body}");
        _logger.e(
          'STT API Error: ${response.statusCode}',
          error: response.body,
        );
        throw Exception(
          'STT API Error: ${response.statusCode} - ${response.body}',
        );
      }

      // Parse response
      print("[STT_DEBUG] Parsing API response");
      final responseJson = jsonDecode(response.body);
      final results = <SpeechRecognitionResult>[];

      for (final result in responseJson['results']) {
        print("[STT_DEBUG] Processing result: $result");
        results.add(SpeechRecognitionResult.fromJson(result));
      }

      print("[STT_DEBUG] Parsed ${results.length} results");
      return results;
    } catch (e, stacktrace) {
      print("[STT_DEBUG] Error in transcribeAudio: $e");
      print("[STT_DEBUG] Stack trace: $stacktrace");
      _logger.e('Error in transcribeAudio', error: e, stackTrace: stacktrace);
      throw Exception('Error in transcribeAudio: $e');
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    print("[STT_DEBUG] dispose called");
    await stopStreaming();
    _isInitialized = false;
    print("[STT_DEBUG] Resources disposed");
  }
}

/// Model class for speech recognition results
class SpeechRecognitionResult {
  /// Recognized text
  final String transcript;

  /// Confidence score (0.0 to 1.0)
  final double confidence;

  /// Whether this is a final result
  final bool isFinal;

  /// Stability score for streaming results (0.0 to 1.0)
  final double stability;

  /// Creates a new [SpeechRecognitionResult]
  SpeechRecognitionResult({
    required this.transcript,
    required this.confidence,
    required this.isFinal,
    this.stability = 0.0,
  });

  /// Create result from JSON
  factory SpeechRecognitionResult.fromJson(Map<String, dynamic> json) {
    print("[STT_DEBUG] Creating SpeechRecognitionResult from JSON: $json");

    // Extract the transcript from either streaming or batch response format
    String transcript = '';
    double confidence = 0.0;
    bool isFinal = false;
    double stability = 0.0;

    if (json.containsKey('results')) {
      print("[STT_DEBUG] Batch response format detected");
      // Batch response format
      final alternatives = json['results'][0]['alternatives'];
      if (alternatives.isNotEmpty) {
        transcript = alternatives[0]['transcript'] ?? '';
        confidence = alternatives[0]['confidence']?.toDouble() ?? 0.0;
      }
      isFinal = true;
    } else if (json.containsKey('result')) {
      print("[STT_DEBUG] Streaming response format detected");
      // Streaming response format
      final result = json['result'];

      if (result.containsKey('alternatives') &&
          result['alternatives'].isNotEmpty) {
        transcript = result['alternatives'][0]['transcript'] ?? '';
        confidence = result['alternatives'][0]['confidence']?.toDouble() ?? 0.0;
      }

      isFinal = result['isFinal'] ?? false;
      stability = result['stability']?.toDouble() ?? 0.0;
    }

    print(
      "[STT_DEBUG] Created result: transcript='$transcript', isFinal=$isFinal",
    );
    return SpeechRecognitionResult(
      transcript: transcript,
      confidence: confidence,
      isFinal: isFinal,
      stability: stability,
    );
  }
}

// Helper function to calculate minimum of two values
int min(int a, int b) => a < b ? a : b;
