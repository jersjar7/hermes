// lib/core/services/translation/translation_service_impl.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'translation_service.dart';
import 'translation_result.dart';

class TranslationServiceImpl implements ITranslationService {
  /// API key loaded from .env
  final String apiKey;

  /// Base URL loaded from .env
  final String baseUrl;

  TranslationServiceImpl({required this.apiKey})
    : baseUrl = dotenv.env['TRANSLATION_API_BASE_URL']!;

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLanguageCode,
    String? sourceLanguageCode,
  }) async {
    // Build the URL from environment
    final uri = Uri.parse('$baseUrl?key=$apiKey');

    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'q': text,
        'target': targetLanguageCode,
        if (sourceLanguageCode != null) 'source': sourceLanguageCode,
        'format': 'text',
      }),
    );

    if (response.statusCode != 200) {
      throw Exception('Translation failed: ${response.body}');
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final translated =
        data['data']['translations'][0]['translatedText'] as String;

    return TranslationResult(
      translatedText: translated,
      targetLanguageCode: targetLanguageCode,
      sourceLanguageCode: sourceLanguageCode,
      originalText: text,
    );
  }
}
