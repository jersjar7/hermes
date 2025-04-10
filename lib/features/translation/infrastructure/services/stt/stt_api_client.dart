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
  final String _apiVersion = 'v2';

  /// Creates a new [SttApiClient]
  SttApiClient(this._httpClient, this._logger, {String? apiKey})
    : _apiKey = apiKey ?? Env.googleCloudApiKey;

  /// Transcribe audio in streaming mode
  Stream<SpeechRecognitionResult> streamingRecognize({
    required Stream<Uint8List> audioStream,
    required SttConfig config,
    required String projectId,
  }) async* {
    final projectId = Env.firebaseProjectId;
    final endpoint =
        '$_apiVersion/projects/$projectId/locations/global:recognizeStream';
    final uri = Uri.https(_apiBaseUrl, endpoint, {'key': _apiKey});

    _logger.d('Creating STT streaming request to: $uri');

    final streamedRequest = http.StreamedRequest('POST', uri);
    streamedRequest.headers['Content-Type'] = 'application/json+stream';

    // Send initial configuration
    final configJson = jsonEncode(config.toJson());
    _logger.d('Sending STT config: $configJson');
    streamedRequest.sink.add(utf8.encode('$configJson\n'));

    // Set up audio forwarding
    final completer = Completer<void>();
    audioStream.listen(
      (audioData) {
        // Convert to base64
        final base64Audio = base64Encode(audioData);

        // Create audio content message
        final audioJson = jsonEncode({
          'audio': {'content': base64Audio},
        });

        // Send to STT API
        streamedRequest.sink.add(utf8.encode('$audioJson\n'));
      },
      onError: (error) {
        _logger.e('Error in audio stream', error: error);
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      onDone: () {
        _logger.d('Audio stream completed, closing request');
        streamedRequest.sink.close();
        if (!completer.isCompleted) {
          completer.complete();
        }
      },
      cancelOnError: true,
    );

    try {
      // Send the request
      final streamedResponse = await _httpClient.send(streamedRequest);

      if (streamedResponse.statusCode != 200) {
        final errorBody = await streamedResponse.stream.bytesToString();
        throw SttApiException(
          'API returned status ${streamedResponse.statusCode}',
          statusCode: streamedResponse.statusCode,
          responseBody: errorBody,
        );
      }

      // Process the streaming response
      String buffer = '';

      await for (final chunk in streamedResponse.stream) {
        buffer += utf8.decode(chunk);

        // Process complete JSON objects (separated by newlines)
        final lines = buffer.split('\n');
        buffer = lines.removeLast(); // Keep incomplete data in buffer

        for (final line in lines) {
          if (line.trim().isEmpty) continue;

          try {
            final json = jsonDecode(line);
            final result = SpeechRecognitionResult.fromJson(json);
            yield result;
          } catch (e) {
            _logger.e('Error parsing STT response line: "$line"', error: e);
          }
        }
      }

      // Process any remaining data in buffer
      if (buffer.isNotEmpty) {
        try {
          final json = jsonDecode(buffer);
          final result = SpeechRecognitionResult.fromJson(json);
          yield result;
        } catch (e) {
          _logger.e('Error parsing final STT response: "$buffer"', error: e);
        }
      }
    } catch (e, stackTrace) {
      if (e is SttApiException) {
        rethrow;
      }
      _logger.e(
        'Error in STT streaming request',
        error: e,
        stackTrace: stackTrace,
      );
      throw SttApiException('Error in STT streaming request: $e');
    }
  }

  /// Transcribe audio in batch mode (non-streaming)
  Future<List<SpeechRecognitionResult>> recognize({
    required Uint8List audioData,
    required SttConfig config,
  }) async {
    final projectId = Env.firebaseProjectId;
    final endpoint =
        '$_apiVersion/projects/$projectId/locations/global:recognize';
    final uri = Uri.https(_apiBaseUrl, endpoint, {'key': _apiKey});

    _logger.d('Creating STT batch request to: $uri');

    // Encode audio as base64
    final base64Audio = base64Encode(audioData);

    // Create request body
    final requestBody = jsonEncode({
      ...config.toBatchJson(),
      'audio': {'content': base64Audio},
    });

    try {
      // Send request
      final response = await _httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode != 200) {
        throw SttApiException(
          'API returned status ${response.statusCode}',
          statusCode: response.statusCode,
          responseBody: response.body,
        );
      }

      // Parse response
      final responseJson = jsonDecode(response.body);
      final results = <SpeechRecognitionResult>[];

      if (responseJson.containsKey('results')) {
        for (final result in responseJson['results']) {
          results.add(
            SpeechRecognitionResult.fromJson({
              'results': [result],
            }),
          );
        }
      }

      return results;
    } catch (e, stackTrace) {
      if (e is SttApiException) {
        rethrow;
      }
      _logger.e('Error in STT batch request', error: e, stackTrace: stackTrace);
      throw SttApiException('Error in STT batch request: $e');
    }
  }
}
