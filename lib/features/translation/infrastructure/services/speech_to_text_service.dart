import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:hermes/config/env.dart';
import 'package:hermes/core/utils/logger.dart';

/// Service to handle speech-to-text operations using Google Cloud STT
class SpeechToTextService {
  final Logger _logger;
  final http.Client _httpClient;
  final Record _recorder;

  bool _isInitialized = false;
  bool _isRecording = false;
  StreamController<Uint8List>? _audioStreamController;
  StreamSubscription? _audioSubscription;

  final String _apiKey = Env.googleCloudApiKey;
  final String _apiBaseUrl = 'speech.googleapis.com';

  /// Creates a new [SpeechToTextService]
  SpeechToTextService(this._logger, this._httpClient, this._recorder);

  /// Factory constructor for dependency injection
  @factoryMethod
  static SpeechToTextService create(Logger logger) {
    return SpeechToTextService(logger, http.Client(), Record());
  }

  /// Initialize the service
  Future<bool> init() async {
    if (_isInitialized) return true;

    try {
      // Check microphone permission
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        _logger.e('Microphone permission not granted');
        return false;
      }

      // Check if recorder is available
      final isRecorderReady = await _recorder.isEncoderSupported(
        AudioEncoder.pcm16bits,
      );

      if (!isRecorderReady) {
        _logger.e('Recorder is not ready or PCM16 is not supported');
        return false;
      }

      _isInitialized = true;
      return true;
    } catch (e, stacktrace) {
      _logger.e(
        'Failed to initialize STT service',
        error: e,
        stackTrace: stacktrace,
      );
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
    if (!_isInitialized) {
      final initialized = await init();
      if (!initialized) {
        throw Exception('STT Service could not be initialized');
      }
    }

    if (_isRecording) {
      await stopStreaming();
    }

    try {
      _audioStreamController = StreamController<Uint8List>.broadcast();
      _isRecording = true;

      // Prepare temporary directory for recording
      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}/temp_${DateTime.now().millisecondsSinceEpoch}.pcm';

      // Configure recording
      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits,
        sampleRate: 16000,
        numChannels: 1,
        autoGain: true,
        echoCancel: true,
        noiseSuppress: true,
      );

      // Start recording with data stream
      await _recorder.start(config: config, path: tempPath);

      // Stream audio data in chunks
      _audioSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amplitude) async {
            if (!_isRecording) return;

            try {
              // Read audio data (in a real implementation, you'd need to read the actual audio data)
              // For this simplified version, we're just checking if the file exists and has data
              final file = File(tempPath);
              if (await file.exists()) {
                final bytes = await file.readAsBytes();
                if (bytes.isNotEmpty) {
                  _audioStreamController?.add(bytes);
                }
              }
            } catch (e) {
              _logger.e('Error reading audio data', error: e);
            }
          });

      // Create a stream to send audio data to Google STT
      final sttStream = _createSttStream(
        sessionId: sessionId,
        languageCode: languageCode,
        audioStream: _audioStreamController!.stream,
      );

      // Yield recognition results
      await for (final result in sttStream) {
        yield result;
      }
    } catch (e, stacktrace) {
      _logger.e('Error in STT streaming', error: e, stackTrace: stacktrace);
      await stopStreaming();
      throw Exception('Error in STT streaming: $e');
    }
  }

  /// Stop streaming audio
  Future<void> stopStreaming() async {
    if (!_isRecording) return;

    try {
      // Stop recording
      if (_recorder.isRecording()) {
        await _recorder.stop();
      }

      // Cancel subscriptions
      await _audioSubscription?.cancel();
      await _audioStreamController?.close();

      _isRecording = false;
      _audioSubscription = null;
      _audioStreamController = null;
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
    if (!_isRecording) return;

    try {
      if (_recorder.isRecording()) {
        await _recorder.pause();
      }
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
    if (!_isRecording) return;

    try {
      if (_recorder.isPaused()) {
        await _recorder.resume();
      }
    } catch (e, stacktrace) {
      _logger.e(
        'Error resuming STT streaming',
        error: e,
        stackTrace: stacktrace,
      );
    }
  }

  /// Create a stream to send audio data to Google STT
  Stream<SpeechRecognitionResult> _createSttStream({
    required String sessionId,
    required String languageCode,
    required Stream<Uint8List> audioStream,
  }) async* {
    // Setup Google Cloud Speech-to-Text V2 streaming API connection
    final uri = Uri.https(
      _apiBaseUrl,
      'v2/projects/${Env.firebaseProjectId}/locations/global:recognizeStream',
      {'key': _apiKey},
    );

    final streamedRequest = http.StreamedRequest('POST', uri);
    streamedRequest.headers['Content-Type'] =
        'application/json+stream'; // Correct Content-Type for streaming

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

    // Send config first
    streamedRequest.sink.add(utf8.encode('$configJson\n'));

    // Process audio stream
    final audioStreamController = StreamController<Uint8List>();
    audioStream.listen(
      (audioData) {
        // Convert audio data to base64
        final base64Audio = base64Encode(audioData);

        // Create audio content message
        final audioJson = jsonEncode({
          'audio': {'content': base64Audio},
        });

        // Send to STT API
        streamedRequest.sink.add(utf8.encode('$audioJson\n'));
      },
      onDone: () {
        streamedRequest.sink.close();
        audioStreamController.close();
      },
      onError: (error) {
        _logger.e('Error in audio stream', error: error);
        audioStreamController.addError(error);
      },
    );

    try {
      final client = http.Client();
      final streamedResponse = await client.send(streamedRequest);

      if (streamedResponse.statusCode != 200) {
        final body = await streamedResponse.stream.bytesToString();
        _logger.e('STT API Error: ${streamedResponse.statusCode}', error: body);
        throw Exception(
          'STT API Error: ${streamedResponse.statusCode} - $body',
        );
      }

      // Process streaming response (newline-delimited JSON)
      await for (final chunk in streamedResponse.stream) {
        final lines = utf8.decode(chunk).split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          try {
            final json = jsonDecode(line);
            final result = SpeechRecognitionResult.fromJson(json);
            yield result;
          } catch (e, stacktrace) {
            _logger.e(
              'Error parsing STT response line: $line',
              error: e,
              stackTrace: stacktrace,
            );
          }
        }
      }
      client.close(); // Close the client when done
    } catch (e, stacktrace) {
      _logger.e('Error in STT API request', error: e, stackTrace: stacktrace);
      throw Exception('Error in STT API request: $e');
    }
  }

  /// Transcribe a single audio file
  Future<List<SpeechRecognitionResult>> transcribeAudio({
    required Uint8List audioData,
    required String languageCode,
  }) async {
    try {
      final uri = Uri.https(
        _apiBaseUrl,
        'v2/projects/${Env.firebaseProjectId}/locations/global:recognize',
        {'key': _apiKey},
      );

      // Encode audio data as base64
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

      // Send request
      final response = await _httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode != 200) {
        _logger.e(
          'STT API Error: ${response.statusCode}',
          error: response.body,
        );
        throw Exception(
          'STT API Error: ${response.statusCode} - ${response.body}',
        );
      }

      // Parse response
      final responseJson = jsonDecode(response.body);
      final results = <SpeechRecognitionResult>[];

      for (final result in responseJson['results']) {
        results.add(SpeechRecognitionResult.fromJson(result));
      }

      return results;
    } catch (e, stacktrace) {
      _logger.e('Error in transcribeAudio', error: e, stackTrace: stacktrace);
      throw Exception('Error in transcribeAudio: $e');
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await stopStreaming();
    _isInitialized = false;
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
    // Extract the transcript from either streaming or batch response format
    String transcript = '';
    double confidence = 0.0;
    bool isFinal = false;
    double stability = 0.0;

    if (json.containsKey('results')) {
      // Batch response format
      final alternatives = json['results'][0]['alternatives'];
      if (alternatives.isNotEmpty) {
        transcript = alternatives[0]['transcript'] ?? '';
        confidence = alternatives[0]['confidence']?.toDouble() ?? 0.0;
      }
      isFinal = true;
    } else if (json.containsKey('result')) {
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

    return SpeechRecognitionResult(
      transcript: transcript,
      confidence: confidence,
      isFinal: isFinal,
      stability: stability,
    );
  }
}
