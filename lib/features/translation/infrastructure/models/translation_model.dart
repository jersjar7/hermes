// lib/features/translation/infrastructure/models/translation_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hermes/features/translation/domain/entities/translation.dart';

/// Model class for [Translation] entity
class TranslationModel extends Translation {
  /// Creates a new [TranslationModel]
  const TranslationModel({
    required super.id,
    required super.sessionId,
    required super.sourceLanguage,
    required super.targetLanguage,
    required super.sourceText,
    required super.targetText,
    required super.timestamp,
  });

  /// Creates a [TranslationModel] from a JSON map
  factory TranslationModel.fromJson(Map<String, dynamic> json) {
    return TranslationModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      sourceLanguage: json['source_language'] as String,
      targetLanguage: json['target_language'] as String,
      sourceText: json['source_text'] as String,
      targetText: json['target_text'] as String,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
    );
  }

  /// Creates a [TranslationModel] from a [Translation]
  factory TranslationModel.fromEntity(Translation translation) {
    return TranslationModel(
      id: translation.id,
      sessionId: translation.sessionId,
      sourceLanguage: translation.sourceLanguage,
      targetLanguage: translation.targetLanguage,
      sourceText: translation.sourceText,
      targetText: translation.targetText,
      timestamp: translation.timestamp,
    );
  }

  /// Converts the model to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'source_language': sourceLanguage,
      'target_language': targetLanguage,
      'source_text': sourceText,
      'target_text': targetText,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  /// Converts the model to a domain entity
  Translation toEntity() {
    return Translation(
      id: id,
      sessionId: sessionId,
      sourceLanguage: sourceLanguage,
      targetLanguage: targetLanguage,
      sourceText: sourceText,
      targetText: targetText,
      timestamp: timestamp,
    );
  }
}
