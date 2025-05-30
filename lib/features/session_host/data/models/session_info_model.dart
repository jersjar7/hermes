// lib/features/session_host/data/models/session_info_model.dart

import 'package:hermes/features/session_host/domain/entities/session_info.dart';

/// DTO / Model for JSON (de)serialization of SessionInfo.
class SessionInfoModel {
  final String sessionId;
  final String languageCode;
  final DateTime createdAt;

  SessionInfoModel({
    required this.sessionId,
    required this.languageCode,
    required this.createdAt,
  });

  /// Creates a model from a JSON map.
  factory SessionInfoModel.fromJson(Map<String, dynamic> json) {
    return SessionInfoModel(
      sessionId: json['sessionId'] as String,
      languageCode: json['languageCode'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  /// Converts the model into a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'sessionId': sessionId,
      'languageCode': languageCode,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  /// Converts this model into the domain entity.
  SessionInfo toEntity() {
    return SessionInfo(
      sessionId: sessionId,
      languageCode: languageCode,
      createdAt: createdAt,
    );
  }

  /// Creates a model from the domain entity.
  factory SessionInfoModel.fromEntity(SessionInfo entity) {
    return SessionInfoModel(
      sessionId: entity.sessionId,
      languageCode: entity.languageCode,
      createdAt: entity.createdAt,
    );
  }
}
