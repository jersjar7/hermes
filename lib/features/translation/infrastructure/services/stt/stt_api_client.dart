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

  /// Creates a new [SttApiClient]
  SttApiClient(this._httpClient, this._logger, {String? apiKey})
    : _apiKey = apiKey ?? Env.googleCloudApiKey {
    _logger.d(
      "[STT_CLIENT] Initialized with API key: \${_apiKey.substring(0, 5)}...(truncated)",
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

    _logger.d('[STT_CLIENT] Starting streamingRecognize to: \$uri');

    final streamedRequest = http.StreamedRequest('POST', uri);
    streamedRequest.headers['Content-Type'] = 'application/json+stream';

    final configJson = jsonEncode({
      'streamingConfig': config.toStreamingConfig(),
    });
    streamedRequest.sink.add(utf8.encode('$configJson\n'));

    audioStream.listen(
      (audioData) {
        final base64Audio = base64Encode(audioData);
        final audioJson = jsonEncode({'audioContent': base64Audio});
        streamedRequest.sink.add(utf8.encode('$audioJson\n'));
      },
      onError: (error) {
        _logger.e('[STT_CLIENT] Error in audio stream', error: error);
        streamedRequest.sink.close();
      },
      onDone: () {
        _logger.d('[STT_CLIENT] Audio stream completed');
        streamedRequest.sink.close();
      },
    );

    final response = await _httpClient.send(streamedRequest);
    if (response.statusCode != 200) {
      final errorBody = await response.stream.bytesToString();
      throw SttApiException(
        'STT API error: \${response.statusCode}',
        statusCode: response.statusCode,
        responseBody: errorBody,
      );
    }

    await for (final chunk in response.stream.transform(utf8.decoder)) {
      for (final line in chunk.split('\n')) {
        if (line.trim().isEmpty) continue;
        try {
          final json = jsonDecode(line);
          final result = SpeechRecognitionResult.fromJson(json);
          yield result;
        } catch (e) {
          _logger.e('Error parsing STT chunk: \$line', error: e);
        }
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

    _logger.d('[STT_CLIENT] Sending batch STT request to: \$uri');

    final base64Audio = base64Encode(audioData);
    final requestBody = jsonEncode(config.toJsonWithAudioContent(base64Audio));

    final response = await _httpClient.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    );

    if (response.statusCode != 200) {
      throw SttApiException(
        'STT batch error: \${response.statusCode}',
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
