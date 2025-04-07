// lib/config/firebase_config.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:injectable/injectable.dart';

/// Class for setting up Firebase services for dependency injection
@module
abstract class FirebaseInjectableModule {
  /// Provides Firebase Auth instance
  @lazySingleton
  FirebaseAuth get firebaseAuth => FirebaseAuth.instance;

  /// Provides Firestore instance
  @lazySingleton
  FirebaseFirestore get firestore => FirebaseFirestore.instance;

  /// Provides Firebase Storage instance
  @lazySingleton
  FirebaseStorage get firebaseStorage => FirebaseStorage.instance;
}

/// Configuration for Firestore collections
class FirestoreCollections {
  /// Collection of users
  static const String users = 'users';

  /// Collection of sessions
  static const String sessions = 'sessions';

  /// Collection of translations
  static const String translations = 'translations';

  /// Collection of transcripts
  static const String transcripts = 'transcripts';

  /// Collection of audio chunks
  static const String audioChunks = 'audio_chunks';

  /// Collection of language preferences
  static const String languagePreferences = 'language_preferences';
}

/// User fields for Firestore documents
class UserFields {
  /// User ID field
  static const String id = 'id';

  /// User name field
  static const String name = 'name';

  /// User email field
  static const String email = 'email';

  /// User created at field
  static const String createdAt = 'created_at';

  /// User updated at field
  static const String updatedAt = 'updated_at';

  /// User sessions field
  static const String sessions = 'sessions';

  /// User language preference field
  static const String languagePreference = 'language_preference';
}

/// Session fields for Firestore documents
class SessionFields {
  /// Session ID field
  static const String id = 'id';

  /// Session code field
  static const String code = 'code';

  /// Session name field
  static const String name = 'name';

  /// Session speaker ID field
  static const String speakerId = 'speaker_id';

  /// Session created at field
  static const String createdAt = 'created_at';

  /// Session updated at field
  static const String updatedAt = 'updated_at';

  /// Session status field
  static const String status = 'status';

  /// Session language field
  static const String language = 'language';

  /// Session listeners field
  static const String listeners = 'listeners';

  /// Session ended at field
  static const String endedAt = 'ended_at';
}

/// Translation fields for Firestore documents
class TranslationFields {
  /// Translation ID field
  static const String id = 'id';

  /// Translation session ID field
  static const String sessionId = 'session_id';

  /// Translation source language field
  static const String sourceLanguage = 'source_language';

  /// Translation target language field
  static const String targetLanguage = 'target_language';

  /// Translation source text field
  static const String sourceText = 'source_text';

  /// Translation target text field
  static const String targetText = 'target_text';

  /// Translation timestamp field
  static const String timestamp = 'timestamp';
}

/// Transcript fields for Firestore documents
class TranscriptFields {
  /// Transcript ID field
  static const String id = 'id';

  /// Transcript session ID field
  static const String sessionId = 'session_id';

  /// Transcript text field
  static const String text = 'text';

  /// Transcript language field
  static const String language = 'language';

  /// Transcript timestamp field
  static const String timestamp = 'timestamp';

  /// Transcript is final field
  static const String isFinal = 'is_final';
}

/// Configuration for Firebase Storage paths
class StoragePaths {
  /// Audio files path
  static const String audioFiles = 'audio_files';

  /// Get the audio file path for a specific session
  static String audioFileForSession(String sessionId, String fileName) =>
      '$audioFiles/$sessionId/$fileName';
}

/// Firebase query helpers
class FirebaseQueryHelpers {
  /// Get sessions ordered by creation date
  static Query<Map<String, dynamic>> sessionsOrderedByDate() {
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.sessions)
        .orderBy(SessionFields.createdAt, descending: true);
  }

  /// Get active sessions
  static Query<Map<String, dynamic>> activeSessions() {
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.sessions)
        .where(SessionFields.status, isEqualTo: 'active');
  }

  /// Get user sessions
  static Query<Map<String, dynamic>> userSessions(String userId) {
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.sessions)
        .where(SessionFields.speakerId, isEqualTo: userId)
        .orderBy(SessionFields.createdAt, descending: true);
  }

  /// Get session by code
  static Query<Map<String, dynamic>> sessionByCode(String code) {
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.sessions)
        .where(SessionFields.code, isEqualTo: code)
        .where(SessionFields.status, isEqualTo: 'active')
        .limit(1);
  }

  /// Get translations for session and language
  static Query<Map<String, dynamic>> translationsForSessionAndLanguage(
    String sessionId,
    String targetLanguage,
  ) {
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.translations)
        .where(TranslationFields.sessionId, isEqualTo: sessionId)
        .where(TranslationFields.targetLanguage, isEqualTo: targetLanguage)
        .orderBy(TranslationFields.timestamp, descending: true);
  }

  /// Get recent transcripts for session
  static Query<Map<String, dynamic>> recentTranscriptsForSession(
    String sessionId, {
    int limit = 50,
  }) {
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.transcripts)
        .where(TranscriptFields.sessionId, isEqualTo: sessionId)
        .where(TranscriptFields.isFinal, isEqualTo: true)
        .orderBy(TranscriptFields.timestamp, descending: true)
        .limit(limit);
  }

  /// Get language preferences for user
  static Query<Map<String, dynamic>> languagePreferencesForUser(String userId) {
    return FirebaseFirestore.instance
        .collection(FirestoreCollections.languagePreferences)
        .where('user_id', isEqualTo: userId);
  }
}

/// Session status enum
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

/// Helper to convert session status enum to string
extension SessionStatusExtension on SessionStatus {
  /// Get string representation of session status
  String get value {
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

  /// Get session status from string
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

/// Firebase timestamp helpers
class FirebaseTimestampHelpers {
  /// Get current timestamp
  static Timestamp get now => Timestamp.now();

  /// Convert DateTime to Timestamp
  static Timestamp fromDateTime(DateTime dateTime) =>
      Timestamp.fromDate(dateTime);

  /// Convert timestamp to DateTime
  static DateTime toDateTime(Timestamp timestamp) => timestamp.toDate();
}
