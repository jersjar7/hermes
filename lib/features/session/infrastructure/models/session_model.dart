// lib/features/session/infrastructure/models/session_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hermes/features/session/domain/entities/session.dart';

/// Model class for [Session] entity
class SessionModel extends Session {
  /// Creates a new [SessionModel]
  const SessionModel({
    required super.id,
    required super.code,
    required super.name,
    required super.speakerId,
    required super.sourceLanguage,
    required super.createdAt,
    required super.status,
    super.listeners = const [],
    super.endedAt,
  });

  /// Creates a [SessionModel] from a JSON map
  factory SessionModel.fromJson(Map<String, dynamic> json) {
    return SessionModel(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      speakerId: json['speaker_id'] as String,
      sourceLanguage: json['source_language'] as String,
      createdAt: (json['created_at'] as Timestamp).toDate(),
      status: SessionStatus.fromString(json['status'] as String),
      listeners: List<String>.from(json['listeners'] ?? []),
      endedAt:
          json['ended_at'] != null
              ? (json['ended_at'] as Timestamp).toDate()
              : null,
    );
  }

  /// Creates a [SessionModel] from a [Session]
  factory SessionModel.fromEntity(Session session) {
    return SessionModel(
      id: session.id,
      code: session.code,
      name: session.name,
      speakerId: session.speakerId,
      sourceLanguage: session.sourceLanguage,
      createdAt: session.createdAt,
      status: session.status,
      listeners: session.listeners,
      endedAt: session.endedAt,
    );
  }

  /// Converts the model to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'speaker_id': speakerId,
      'source_language': sourceLanguage,
      'created_at': Timestamp.fromDate(createdAt),
      'status': status.toValue(),
      'listeners': listeners,
      'ended_at': endedAt != null ? Timestamp.fromDate(endedAt!) : null,
    };
  }

  /// Creates a copy of this model with the given fields replaced
  @override
  SessionModel copyWith({
    String? id,
    String? code,
    String? name,
    String? speakerId,
    String? sourceLanguage,
    DateTime? createdAt,
    SessionStatus? status,
    List<String>? listeners,
    DateTime? endedAt,
  }) {
    return SessionModel(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      speakerId: speakerId ?? this.speakerId,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      createdAt: createdAt ?? this.createdAt,
      status: status ?? this.status,
      listeners: listeners ?? this.listeners,
      endedAt: endedAt ?? this.endedAt,
    );
  }
}
