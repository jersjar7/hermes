// lib/features/translation/domain/entities/translation.dart

import 'package:equatable/equatable.dart';

/// Represents a translation entity in the domain layer
class Translation extends Equatable {
  /// Unique identifier for the translation
  final String id;

  /// ID of the session this translation belongs to
  final String sessionId;

  /// Source language code
  final String sourceLanguage;

  /// Target language code
  final String targetLanguage;

  /// Original text in source language
  final String sourceText;

  /// Translated text in target language
  final String targetText;

  /// When the translation was created
  final DateTime timestamp;

  /// Creates a new [Translation] instance
  const Translation({
    required this.id,
    required this.sessionId,
    required this.sourceLanguage,
    required this.targetLanguage,
    required this.sourceText,
    required this.targetText,
    required this.timestamp,
  });

  /// Creates a copy of this translation with the given fields replaced
  Translation copyWith({
    String? id,
    String? sessionId,
    String? sourceLanguage,
    String? targetLanguage,
    String? sourceText,
    String? targetText,
    DateTime? timestamp,
  }) {
    return Translation(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      sourceText: sourceText ?? this.sourceText,
      targetText: targetText ?? this.targetText,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [
    id,
    sessionId,
    sourceLanguage,
    targetLanguage,
    sourceText,
    targetText,
    timestamp,
  ];
}
