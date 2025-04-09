// lib/features/translation/infrastructure/services/translation_service.dart

import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:injectable/injectable.dart';
import 'package:hermes/config/env.dart';
import 'package:hermes/core/utils/logger.dart';

/// Service to handle translation operations using Google Cloud Translation API
class TranslationService {
  final Logger _logger;
  final http.Client _httpClient;

  final String _apiKey = Env.googleCloudApiKey;
  final String _apiBaseUrl = 'translation.googleapis.com';
  final String _apiVersion = 'v3';
  final String _location = 'global';

  /// Creates a new [TranslationService]
  TranslationService(this._logger, this._httpClient);

  /// Factory constructor for dependency injection
  @factoryMethod
  static TranslationService create(Logger logger) {
    return TranslationService(logger, http.Client());
  }

  /// Translate text to a single target language
  Future<TranslationResult> translateText({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
  }) async {
    try {
      final projectId = Env.firebaseProjectId;
      final endpoint =
          '$_apiVersion/projects/$projectId/locations/$_location:translateText';
      final uri = Uri.https(_apiBaseUrl, endpoint, {'key': _apiKey});

      // Clean language codes (remove region parts if needed)
      final sourceLang = _cleanLanguageCode(sourceLanguage);
      final targetLang = _cleanLanguageCode(targetLanguage);

      // Create request body
      final requestBody = jsonEncode({
        'contents': [text],
        'sourceLanguageCode': sourceLang,
        'targetLanguageCode': targetLang,
        'mimeType': 'text/plain',
      });

      // Send request
      final response = await _httpClient.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      );

      if (response.statusCode != 200) {
        _logger.e(
          'Translation API Error: ${response.statusCode}',
          error: response.body,
        );
        throw Exception(
          'Translation API Error: ${response.statusCode} - ${response.body}',
        );
      }

      // Parse response
      final responseJson = jsonDecode(response.body);
      final translations = responseJson['translations'];

      if (translations == null || translations.isEmpty) {
        throw Exception('No translation received from API');
      }

      final translatedText = translations[0]['translatedText'];
      final detectedLanguage =
          translations[0]['detectedLanguageCode'] ?? sourceLang;

      return TranslationResult(
        originalText: text,
        translatedText: translatedText,
        sourceLanguage: detectedLanguage,
        targetLanguage: targetLang,
      );
    } catch (e, stacktrace) {
      _logger.e('Error in translateText', error: e, stackTrace: stacktrace);
      throw Exception('Error in translateText: $e');
    }
  }

  /// Translate text to multiple target languages
  Future<List<TranslationResult>> translateTextToMultipleLanguages({
    required String text,
    required String sourceLanguage,
    required List<String> targetLanguages,
  }) async {
    final results = <TranslationResult>[];
    final futures = <Future<TranslationResult>>[];

    // Create a batch of translation requests
    for (final targetLanguage in targetLanguages) {
      futures.add(
        translateText(
          text: text,
          sourceLanguage: sourceLanguage,
          targetLanguage: targetLanguage,
        ),
      );
    }

    // Wait for all translations to complete
    try {
      final translationResults = await Future.wait(futures);
      results.addAll(translationResults);
    } catch (e, stacktrace) {
      _logger.e('Error in batch translation', error: e, stackTrace: stacktrace);
      throw Exception('Error in batch translation: $e');
    }

    return results;
  }

  /// Get a list of supported languages
  Future<List<SupportedLanguage>> getSupportedLanguages({
    String? displayLanguage,
  }) async {
    try {
      final projectId = Env.firebaseProjectId;
      final endpoint =
          '$_apiVersion/projects/$projectId/locations/$_location/supportedLanguages';

      final queryParams = <String, String>{'key': _apiKey};
      if (displayLanguage != null) {
        queryParams['displayLanguageCode'] = _cleanLanguageCode(
          displayLanguage,
        );
      }

      final uri = Uri.https(_apiBaseUrl, endpoint, queryParams);

      // Send request
      final response = await _httpClient.get(uri);

      if (response.statusCode != 200) {
        _logger.e(
          'Translation API Error: ${response.statusCode}',
          error: response.body,
        );
        throw Exception(
          'Translation API Error: ${response.statusCode} - ${response.body}',
        );
      }

      // Parse response
      final responseJson = jsonDecode(response.body);
      final languages = responseJson['languages'] as List;

      return languages.map((lang) => SupportedLanguage.fromJson(lang)).toList();
    } catch (e, stacktrace) {
      _logger.e(
        'Error fetching supported languages',
        error: e,
        stackTrace: stacktrace,
      );
      throw Exception('Error fetching supported languages: $e');
    }
  }

  /// Clean language codes to format expected by the API
  String _cleanLanguageCode(String code) {
    // Strip region part if present (e.g., 'en-US' -> 'en')
    final parts = code.split('-');
    return parts.first.toLowerCase();
  }
}

/// Model class for translation results
class TranslationResult {
  /// Original text that was translated
  final String originalText;

  /// Translated text
  final String translatedText;

  /// Source language code
  final String sourceLanguage;

  /// Target language code
  final String targetLanguage;

  /// Creates a new [TranslationResult]
  TranslationResult({
    required this.originalText,
    required this.translatedText,
    required this.sourceLanguage,
    required this.targetLanguage,
  });
}

/// Model class for supported languages
class SupportedLanguage {
  /// Language code (e.g., 'en', 'es', 'fr')
  final String languageCode;

  /// Display name in the requested display language
  final String displayName;

  /// Support level
  final String supportLevel;

  /// Creates a new [SupportedLanguage]
  SupportedLanguage({
    required this.languageCode,
    required this.displayName,
    required this.supportLevel,
  });

  /// Create from JSON
  factory SupportedLanguage.fromJson(Map<String, dynamic> json) {
    return SupportedLanguage(
      languageCode: json['languageCode'] ?? '',
      displayName: json['displayName'] ?? '',
      supportLevel: json['supportLevel'] ?? 'UNKNOWN',
    );
  }
}
