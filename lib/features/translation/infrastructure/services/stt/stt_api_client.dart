// lib/features/translation/infrastructure/services/stt/stt_api_client.dart

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:hermes/config/env.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/models/stt_config.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/models/stt_result.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_exceptions.dart';

/// Client for Google Cloud Speech-to-Text API
class SttApiClient {
  final http.Client _httpClient;
  final Logger _logger;

  final String _apiKey;
  final String _apiBaseUrl = 'speech.googleapis.com';

  // Helper function
  int _min(int a, int b) => a < b ? a : b;

  /// Creates a new [SttApiClient]
  SttApiClient(this._httpClient, this._logger, {String? apiKey})
    : _apiKey = apiKey ?? Env.googleCloudApiKey {
    _logger.d(
      "[STT_CLIENT] Initialized with API key: ${_apiKey.isNotEmpty ? _apiKey.substring(0, _min(5, _apiKey.length)) : '(empty)'}...(truncated)",
    );
  }

  /// Transcribe audio in streaming mode (v1p1beta1)
  Stream<SpeechRecognitionResult> streamingRecognize({
    required Stream<Uint8List> audioStream,
    required SttConfig config,
  }) async* {
    final uri = Uri.https(_apiBaseUrl, 'v1p1beta1/speech:streamingRecognize', {
      'key': _apiKey,
    });

    _logger.d('[STT_CLIENT] Starting streamingRecognize to: $uri');
    _logger.d(
      '[STT_CLIENT] API key status: ${_apiKey.isNotEmpty ? "Valid (${_apiKey.length} chars)" : "Empty/Invalid"}',
    );

    // ADDED: Verify API key is valid
    if (_apiKey.isEmpty) {
      _logger.e('[STT_CLIENT] API key is empty, cannot proceed with API call');
      throw SttApiException('Google Cloud API key is empty');
    }

    final streamedRequest = http.StreamedRequest('POST', uri);
    streamedRequest.headers['Content-Type'] = 'application/json+stream';

    final configJson = jsonEncode({
      'streamingConfig': config.toStreamingConfig(),
    });

    _logger.d(
      '[STT_CLIENT] Sending config: ${configJson.substring(0, _min(100, configJson.length))}...',
    );
    streamedRequest.sink.add(utf8.encode('$configJson\n'));

    // ADDED: Flag to track if we've received any audio data
    bool hasReceivedAudioData = false;

    // CHANGED: Use a Completer to properly handle stream completion
    final completer = Completer<void>();

    // Variable to track if we've attempted to close the sink
    bool sinkCloseAttempted = false;

    // ADDED: Setup subscription and error handling
    final audioSubscription = audioStream.listen(
      (audioData) {
        hasReceivedAudioData = true;
        final base64Audio = base64Encode(audioData);
        if (DateTime.now().millisecondsSinceEpoch % 2000 < 200) {
          _logger.d(
            '[STT_CLIENT] Sending audio chunk: ${audioData.length} bytes',
          );
        }
        final audioJson = jsonEncode({'audioContent': base64Audio});

        // Check if we've already tried to close the sink
        if (!sinkCloseAttempted) {
          try {
            streamedRequest.sink.add(utf8.encode('$audioJson\n'));
          } catch (e) {
            _logger.e(
              '[STT_CLIENT] Error sending audio data to sink',
              error: e,
            );
          }
        }
      },
      onError: (error) {
        _logger.e('[STT_CLIENT] Error in audio stream', error: error);
        // Try to add the error if sink is not already closed
        if (!sinkCloseAttempted) {
          try {
            streamedRequest.sink.addError(error);
          } catch (e) {
            _logger.e('[STT_CLIENT] Error adding error to sink', error: e);
          }
        }
      },
      onDone: () {
        _logger.d('[STT_CLIENT] Audio stream completed');
        if (!hasReceivedAudioData) {
          _logger.e(
            '[STT_CLIENT] Audio stream completed without sending any data!',
          );
        }
        // Try to close the sink if we haven't already attempted it
        if (!sinkCloseAttempted) {
          sinkCloseAttempted = true;
          try {
            streamedRequest.sink.close();
          } catch (e) {
            _logger.e('[STT_CLIENT] Error closing sink', error: e);
          }
        }
      },
    );

    // Ensure we clean up properly
    try {
      final response = await _httpClient.send(streamedRequest);

      if (response.statusCode != 200) {
        final errorBody = await response.stream.bytesToString();
        _logger.e(
          '[STT_CLIENT] API returned error status: ${response.statusCode}',
          error: errorBody,
        );
        throw SttApiException(
          'STT API error: ${response.statusCode}',
          statusCode: response.statusCode,
          responseBody: errorBody,
        );
      }

      // Process response stream
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        for (final line in chunk.split('\n')) {
          if (line.trim().isEmpty) continue;
          try {
            _logger.d('[STT_CLIENT] Received line: $line');
            final json = jsonDecode(line);
            final result = SpeechRecognitionResult.fromJson(json);
            yield result;
          } catch (e) {
            _logger.e('Error parsing STT chunk: $line', error: e);
          }
        }
      }
    } catch (e, stack) {
      _logger.e(
        '[STT_CLIENT] Error in streamingRecognize',
        error: e,
        stackTrace: stack,
      );
      throw SttApiException('Error in STT streaming: $e');
    } finally {
      // Clean up resources
      await audioSubscription.cancel();

      // Make sure to close the sink if we haven't already tried
      if (!sinkCloseAttempted) {
        sinkCloseAttempted = true;
        try {
          streamedRequest.sink.close();
        } catch (e) {
          _logger.e('[STT_CLIENT] Error closing sink during cleanup', error: e);
        }
      }

      if (!completer.isCompleted) {
        completer.complete();
      }
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

    _logger.d('[STT_CLIENT] Sending batch STT request to: $uri');

    final base64Audio = base64Encode(audioData);
    final requestBody = jsonEncode(config.toJsonWithAudioContent(base64Audio));

    final response = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    if (response.statusCode != 200) {
      throw SttApiException(
        'STT batch error: ${response.statusCode}',
        statusCode: response.statusCode,
        responseBody: response.body,
      );
    }

    final responseJson = jsonDecode(response.body);
    final results = <SpeechRecognitionResult>[];

    if (responseJson.containsKey('results')) {
      for (final result in responseJson['results']) {
        final parsedResult = SpeechRecognitionResult.fromJson({
          'results': [result],
        });
        results.add(parsedResult);
      }
    }

    return results;
  }
}
