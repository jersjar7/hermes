// lib/features/translation/infrastructure/models/transcript_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';

/// Model class for [Transcript] entity
class TranscriptModel extends Transcript {
  /// Creates a new [TranscriptModel]
  const TranscriptModel({
    required super.id,
    required super.sessionId,
    required super.text,
    required super.language,
    required super.timestamp,
    super.isFinal,
  });

  /// Creates a [TranscriptModel] from a JSON map
  factory TranscriptModel.fromJson(Map<String, dynamic> json) {
    return TranscriptModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String,
      text: json['text'] as String,
      language: json['language'] as String,
      timestamp: (json['timestamp'] as Timestamp).toDate(),
      isFinal: json['is_final'] as bool? ?? false,
    );
  }

  /// Creates a [TranscriptModel] from a [Transcript]
  factory TranscriptModel.fromEntity(Transcript transcript) {
    return TranscriptModel(
      id: transcript.id,
      sessionId: transcript.sessionId,
      text: transcript.text,
      language: transcript.language,
      timestamp: transcript.timestamp,
      isFinal: transcript.isFinal,
    );
  }

  /// Converts the model to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      'text': text,
      'language': language,
      'timestamp': Timestamp.fromDate(timestamp),
      'is_final': isFinal,
    };
  }

  /// Converts the model to a domain entity
  Transcript toEntity() {
    return Transcript(
      id: id,
      sessionId: sessionId,
      text: text,
      language: language,
      timestamp: timestamp,
      isFinal: isFinal,
    );
  }
}
