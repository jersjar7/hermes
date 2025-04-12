// lib/features/translation/infrastructure/services/stt/stt_api_client.dart
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:hermes/config/env.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/models/stt_config.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/models/stt_result.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_exceptions.dart';

/// Client for Google Cloud Speech-to-Text API
class SttApiClient {
  final http.Client _httpClient;
  final String _apiKey;
  final String _apiBaseUrl = 'speech.googleapis.com';

  // Keep track of the active request
  http.StreamedRequest? _activeRequest;
  bool _isShuttingDown = false;
  // ADDED: Track if any response has been received
  bool _receivedFirstResponse = false;
  // ADDED: Track auth failures
  bool _authFailureDetected = false;

  // Helper function
  int _min(int a, int b) => a < b ? a : b;

  /// Creates a new [SttApiClient]
  SttApiClient(this._httpClient, {String? apiKey})
    : _apiKey = apiKey ?? Env.googleCloudApiKey {
    print(
      "[STT_CLIENT] Initialized with API key: ${_apiKey.isNotEmpty ? _apiKey.substring(0, _min(5, _apiKey.length)) : '(empty)'}...(truncated)",
    );
    // ADDED: Basic validation
    if (_apiKey.isEmpty) {
      print("[STT_CLIENT] WARNING: API key is empty!");
    }
  }

  /// Transcribe audio in streaming mode (v1p1beta1)
  Stream<SpeechRecognitionResult> streamingRecognize({
    required Stream<Uint8List> audioStream,
    required SttConfig config,
  }) async* {
    final uri = Uri.https(_apiBaseUrl, 'v1p1beta1/speech:streamingRecognize', {
      'key': _apiKey,
    });

    print('[STT_CLIENT] Starting streamingRecognize to: $uri');

    // ADDED: Reset tracking variables
    _receivedFirstResponse = false;
    _authFailureDetected = false;

    // Reset the shutdown flag
    _isShuttingDown = false;

    // ADDED: Verify API key is valid
    if (_apiKey.isEmpty) {
      print('[STT_CLIENT] API key is empty, cannot proceed with API call');
      throw SttApiException('Google Cloud API key is empty');
    }

    // Clean up any existing request
    if (_activeRequest != null) {
      try {
        // Try to gracefully close the existing request
        _activeRequest?.sink.close();
      } catch (e) {
        // Ignore errors during cleanup
      }
      _activeRequest = null;
    }

    final streamedRequest = http.StreamedRequest('POST', uri);
    streamedRequest.headers['Content-Type'] = 'application/json';
    _activeRequest = streamedRequest;

    // Create a completer to signal when we're done with this request
    final completer = Completer<void>();

    // Create controllers for coordinating audio data and API responses
    final audioController = StreamController<Uint8List>();
    final responseController = StreamController<SpeechRecognitionResult>();

    // Track if we've successfully started the stream
    bool streamStarted = false;
    bool hasError = false;

    // Function to clean up all resources
    // MOVED: Declare the cleanupResources function before using it
    void cleanupResources() async {
      if (_isShuttingDown) return; // Prevent multiple cleanups
      _isShuttingDown = true;

      try {
        print('[STT_CLIENT] Cleaning up resources...');

        // Cancel all subscriptions and close controllers
        await audioController.close();

        // Only close response controller if it's not already closed
        if (!responseController.isClosed) {
          await responseController.close();
        }

        // Signal completion
        if (!completer.isCompleted) {
          completer.complete();
        }

        // Clean up request
        if (_activeRequest != null && _activeRequest == streamedRequest) {
          try {
            await _activeRequest?.sink.close();
          } catch (e) {
            // Ignore errors during cleanup
          }
          _activeRequest = null;
        }

        print('[STT_CLIENT] Resources cleanup completed');
      } catch (e) {
        print('[STT_CLIENT] Error during cleanup: $e');
      }
    }

    // ADDED: Setup timeout timer
    Timer? timeoutTimer;
    timeoutTimer = Timer(const Duration(seconds: 15), () {
      if (!_receivedFirstResponse && !hasError) {
        print(
          '[STT_CLIENT] No response received after 15 seconds - timing out',
        );
        hasError = true;
        responseController.addError(
          SttApiException('No response received from STT API after 15 seconds'),
        );
        cleanupResources();
      }
    });

    // Send the configuration as the first message
    final configJson = jsonEncode({
      'streamingConfig': config.toStreamingConfig(),
    });

    print(
      '[STT_CLIENT] Sending config: ${configJson.substring(0, _min(100, configJson.length))}...',
    );

    // Connect the audio stream to the HTTP request
    StreamSubscription? audioSubscription;

    try {
      // First send the config
      streamedRequest.sink.add(utf8.encode('$configJson\n'));

      // Create a subscription to the audio stream
      audioSubscription = audioStream.listen(
        (audioData) {
          if (_isShuttingDown) return; // Skip if we're shutting down

          // ADDED: Skip sending if auth failure detected
          if (_authFailureDetected) return;

          try {
            if (streamedRequest.sink is IOSink) {
              final base64Audio = base64Encode(audioData);
              final audioJson = jsonEncode({'audioContent': base64Audio});
              streamedRequest.sink.add(utf8.encode('$audioJson\n'));

              // Log periodically to avoid flooding
              if (DateTime.now().millisecondsSinceEpoch % 5000 < 100) {
                print(
                  '[STT_CLIENT] Sent audio chunk: ${audioData.length} bytes',
                );
              }
            }
          } catch (e) {
            print('[STT_CLIENT] Error sending audio data: $e');
            if (!hasError) {
              hasError = true;
              responseController.addError(
                SttApiException('Error sending audio: ${e.toString()}'),
              );
            }
            cleanupResources();
          }
        },
        onError: (error) {
          print('[STT_CLIENT] Error in audio stream: $error');
          if (!hasError) {
            hasError = true;
            responseController.addError(error);
          }
          cleanupResources();
        },
        onDone: () {
          print('[STT_CLIENT] Audio stream completed');
          // Try to finish the request gracefully
          try {
            if (!_isShuttingDown) {
              streamedRequest.sink.close();
            }
          } catch (e) {
            print('[STT_CLIENT] Error closing sink after audio completion: $e');
          }
        },
      );

      // Process the HTTP response
      streamedRequest
          .send()
          .then((response) async {
            streamStarted = true;

            // ADDED: Check for auth errors
            if (response.statusCode == 401 || response.statusCode == 403) {
              _authFailureDetected = true;
              hasError = true;
              final errorBody = await response.stream.bytesToString();
              print(
                '[STT_CLIENT] Authentication error: ${response.statusCode}, body: $errorBody',
              );
              responseController.addError(
                SttApiException(
                  'Authentication error: Please check your Google Cloud API key',
                  statusCode: response.statusCode,
                  responseBody: errorBody,
                ),
              );
              cleanupResources();
              return;
            }

            if (response.statusCode != 200) {
              final errorBody = await response.stream.bytesToString();
              print(
                '[STT_CLIENT] API returned error status: ${response.statusCode}, body: $errorBody',
              );

              if (!hasError) {
                hasError = true;
                responseController.addError(
                  SttApiException(
                    'STT API error: ${response.statusCode}',
                    statusCode: response.statusCode,
                    responseBody: errorBody,
                  ),
                );
              }
              cleanupResources();
              return;
            }

            // Process the response stream
            response.stream
                .transform(utf8.decoder)
                .transform(const LineSplitter())
                .listen(
                  (line) {
                    if (line.trim().isEmpty) return;

                    // ADDED: Record successful response
                    if (!_receivedFirstResponse) {
                      _receivedFirstResponse = true;
                      print('[STT_CLIENT] Received first response from API');
                      // Cancel timeout timer
                      timeoutTimer?.cancel();
                    }

                    try {
                      final json = jsonDecode(line);

                      // ADDED: Check for error response
                      if (json.containsKey('error')) {
                        print(
                          '[STT_CLIENT] Received error response: ${json['error']}',
                        );
                        if (!hasError) {
                          hasError = true;
                          responseController.addError(
                            SttApiException(
                              'API error response: ${json['error']}',
                            ),
                          );
                        }
                        return;
                      }

                      final result = SpeechRecognitionResult.fromJson(json);

                      // Only forward non-empty results
                      if (result.transcript.isNotEmpty) {
                        responseController.add(result);
                      }
                    } catch (e) {
                      print('Error parsing STT chunk: $line, error: $e');
                      // Don't forward parsing errors, just log them
                    }
                  },
                  onError: (error) {
                    print('[STT_CLIENT] Error in response stream: $error');
                    if (!hasError) {
                      hasError = true;
                      responseController.addError(error);
                    }
                    cleanupResources();
                  },
                  onDone: () {
                    print('[STT_CLIENT] Response stream completed');
                    cleanupResources();
                  },
                );
          })
          .catchError((error) {
            print('[STT_CLIENT] Error sending request: $error');
            if (!hasError) {
              hasError = true;
              responseController.addError(
                SttApiException('Error sending request: ${error.toString()}'),
              );
            }
            cleanupResources();
          });

      // Set up response forwarding
      await for (final result in responseController.stream) {
        yield result;
      }
    } catch (e, stack) {
      print(
        '[STT_CLIENT] Error in streamingRecognize: $e\nStack trace: $stack',
      );

      if (!streamStarted) {
        // If the stream never started, throw immediately
        throw SttApiException('Error in STT streaming: $e');
      } else {
        // If the stream started but had an error, clean up
        cleanupResources();
        rethrow;
      }
    } finally {
      // Ensure all resources are cleaned up
      await audioSubscription?.cancel();
      cleanupResources();
    }
  }

  /// Transcribe audio in batch mode (v1p1beta1)
  Future<List<SpeechRecognitionResult>> recognize({
    required Uint8List audioData,
    required SttConfig config,
  }) async {
    final uri = Uri.https(_apiBaseUrl, 'v1p1beta1/speech:recognize', {
      'key': _apiKey,
    });

    print('[STT_CLIENT] Sending batch STT request to: $uri');

    // ADDED: Add validation
    if (_apiKey.isEmpty) {
      throw SttApiException('Google Cloud API key is empty');
    }

    final base64Audio = base64Encode(audioData);
    final requestBody = jsonEncode(config.toJsonWithAudioContent(base64Audio));

    // ADDED: Timeout for batch requests
    final response = await _httpClient
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: requestBody,
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw SttApiException('STT API request timed out after 30 seconds');
          },
        );

    // ADDED: Better error handling
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw SttApiException(
        'Authentication error: Please check your Google Cloud API key',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    if (response.statusCode != 200) {
      throw SttApiException(
        'STT batch error: ${response.statusCode}',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    // ADDED: Better response parsing with error handling
    try {
      final responseJson = jsonDecode(response.body);
      final results = <SpeechRecognitionResult>[];

      print(
        '[STT_CLIENT] Received batch response: ${response.body.substring(0, _min(100, response.body.length))}...',
      );

      if (responseJson.containsKey('error')) {
        throw SttApiException(
          'API error response: ${responseJson['error']}',
          responseBody: response.body,
        );
      }

      if (responseJson.containsKey('results')) {
        for (final result in responseJson['results']) {
          final parsedResult = SpeechRecognitionResult.fromJson({
            'results': [result],
          });
          results.add(parsedResult);
        }
      }

      return results;
    } catch (e) {
      print('[STT_CLIENT] Error parsing batch response: $e');
      throw SttApiException('Error parsing STT response: $e');
    }
  }

  /// Cancel any active request
  Future<void> cancelActiveRequest() async {
    _isShuttingDown = true;

    if (_activeRequest != null) {
      print('[STT_CLIENT] Canceling active request');
      try {
        await _activeRequest?.sink.close();
      } catch (e) {
        // Ignore errors during cancellation
        print('[STT_CLIENT] Error during request cancellation: $e');
      }
      _activeRequest = null;
    }
  }
}
