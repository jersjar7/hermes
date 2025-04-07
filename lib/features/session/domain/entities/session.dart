// lib/features/session/domain/entities/session.dart

import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a session entity in the domain layer
class Session extends Equatable {
  /// Unique identifier for the session
  final String id;

  /// Code that users enter to join the session
  final String code;

  /// Display name for the session
  final String name;

  /// ID of the user who created the session
  final String speakerId;

  /// Primary language of the speaker
  final String sourceLanguage;

  /// When the session was created
  final DateTime createdAt;

  /// Current status of the session
  final SessionStatus status;

  /// List of user IDs who are listening to the session
  final List<String> listeners;

  /// When the session ended (null if still active)
  final DateTime? endedAt;

  /// Creates a new [Session] instance
  const Session({
    required this.id,
    required this.code,
    required this.name,
    required this.speakerId,
    required this.sourceLanguage,
    required this.createdAt,
    required this.status,
    this.listeners = const [],
    this.endedAt,
  });

  /// Creates a copy of this session with the given fields replaced
  Session copyWith({
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
    return Session(
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

  @override
  List<Object?> get props => [
    id,
    code,
    name,
    speakerId,
    sourceLanguage,
    createdAt,
    status,
    listeners,
    endedAt,
  ];
}

/// Possible statuses for a session
enum SessionStatus {
  /// Session is being created
  creating,

  /// Session is active
  active,

  /// Session is paused
  paused,

  /// Session has ended
  ended,

  /// Session has an error
  error,
}

/// Extensions for [SessionStatus] enum
extension SessionStatusX on SessionStatus {
  /// Convert [SessionStatus] to string
  String toValue() {
    switch (this) {
      case SessionStatus.creating:
        return 'creating';
      case SessionStatus.active:
        return 'active';
      case SessionStatus.paused:
        return 'paused';
      case SessionStatus.ended:
        return 'ended';
      case SessionStatus.error:
        return 'error';
    }
  }

  /// Create [SessionStatus] from string
  static SessionStatus fromString(String value) {
    switch (value) {
      case 'creating':
        return SessionStatus.creating;
      case 'active':
        return SessionStatus.active;
      case 'paused':
        return SessionStatus.paused;
      case 'ended':
        return SessionStatus.ended;
      case 'error':
        return SessionStatus.error;
      default:
        return SessionStatus.error;
    }
  }
}
