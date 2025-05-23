import 'dart:convert';
import 'package:http/http.dart' as http;

import 'translation_service.dart';
import 'translation_result.dart'; // 👈 new import

class TranslationServiceImpl implements ITranslationService {
  final String apiKey;

  TranslationServiceImpl({required this.apiKey});

  @override
  Future<TranslationResult> translate({
    required String text,
    required String targetLanguageCode,
    String? sourceLanguageCode,
  }) async {
    final url = Uri.parse(
      'https://translation.googleapis.com/language/translate/v2?key=$apiKey',
    );

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'q': text,
        'target': targetLanguageCode,
        if (sourceLanguageCode != null) 'source': sourceLanguageCode,
        'format': 'text',
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return TranslationResult(
        translatedText: data['data']['translations'][0]['translatedText'],
        targetLanguageCode: targetLanguageCode,
        sourceLanguageCode: sourceLanguageCode,
        originalText: text,
      );
    } else {
      throw Exception('Failed to translate text: ${response.body}');
    }
  }
}
