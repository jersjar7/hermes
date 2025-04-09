// lib/features/translation/domain/entities/transcript.dart

import 'package:equatable/equatable.dart';

/// Represents a transcript entity in the domain layer
class Transcript extends Equatable {
  /// Unique identifier for the transcript
  final String id;

  /// ID of the session this transcript belongs to
  final String sessionId;

  /// The transcribed text
  final String text;

  /// Language code of the transcript
  final String language;

  /// When the transcript was created
  final DateTime timestamp;

  /// Whether this is a final result from the Speech-to-Text service
  final bool isFinal;

  /// Creates a new [Transcript] instance
  const Transcript({
    required this.id,
    required this.sessionId,
    required this.text,
    required this.language,
    required this.timestamp,
    this.isFinal = false,
  });

  /// Creates a copy of this transcript with the given fields replaced
  Transcript copyWith({
    String? id,
    String? sessionId,
    String? text,
    String? language,
    DateTime? timestamp,
    bool? isFinal,
  }) {
    return Transcript(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      text: text ?? this.text,
      language: language ?? this.language,
      timestamp: timestamp ?? this.timestamp,
      isFinal: isFinal ?? this.isFinal,
    );
  }

  @override
  List<Object?> get props => [
    id,
    sessionId,
    text,
    language,
    timestamp,
    isFinal,
  ];
}
