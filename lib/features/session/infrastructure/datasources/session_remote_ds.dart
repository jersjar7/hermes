// lib/features/session/infrastructure/datasources/session_remote_ds.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:injectable/injectable.dart';
import 'package:hermes/config/firebase_config.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/session/infrastructure/models/session_model.dart';

/// Exception thrown when a session is not found
class SessionNotFoundException implements Exception {
  final String message;
  SessionNotFoundException([this.message = 'Session not found']);

  @override
  String toString() => message;
}

/// Remote data source for session operations
@lazySingleton
class SessionRemoteDataSource {
  final FirebaseFirestore _firestore;
  final firebase_auth.FirebaseAuth _auth;
  final Logger _logger;

  /// Creates a new [SessionRemoteDataSource]
  SessionRemoteDataSource(this._firestore, this._auth, this._logger);

  /// Creates a new session
  Future<SessionModel> createSession({
    required String name,
    required String code,
    required String speakerId,
    required String sourceLanguage,
  }) async {
    try {
      // Create a document reference with auto ID
      final sessionRef =
          _firestore.collection(FirestoreCollections.sessions).doc();

      final now = DateTime.now();
      final session = SessionModel(
        id: sessionRef.id,
        code: code,
        name: name,
        speakerId: speakerId,
        sourceLanguage: sourceLanguage,
        createdAt: now,
        status: SessionStatus.active,
        listeners: [],
      );

      // Save to Firestore
      await sessionRef.set(session.toJson());

      return session;
    } catch (e, stackTrace) {
      _logger.e('Error creating session: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Gets a session by ID
  Future<SessionModel> getSessionById(String sessionId) async {
    try {
      final doc =
          await _firestore
              .collection(FirestoreCollections.sessions)
              .doc(sessionId)
              .get();

      if (!doc.exists) {
        throw SessionNotFoundException();
      }

      return SessionModel.fromJson(doc.data()!);
    } catch (e, stackTrace) {
      _logger.e(
        'Error getting session by ID: $e',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Gets a session by code
  Future<SessionModel> getSessionByCode(String code) async {
    try {
      final querySnapshot =
          await _firestore
              .collection(FirestoreCollections.sessions)
              .where('code', isEqualTo: code)
              .where('status', isEqualTo: SessionStatus.active.toValue())
              .limit(1)
              .get();

      if (querySnapshot.docs.isEmpty) {
        throw SessionNotFoundException(
          'No active session found with code: $code',
        );
      }

      return SessionModel.fromJson(querySnapshot.docs.first.data());
    } catch (e, stackTrace) {
      _logger.e(
        'Error getting session by code: $e',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Joins a session
  Future<SessionModel> joinSession({
    required String sessionId,
    required String userId,
  }) async {
    try {
      final sessionRef = _firestore
          .collection(FirestoreCollections.sessions)
          .doc(sessionId);

      // Add user to listeners list if not already there
      await sessionRef.update({
        'listeners': FieldValue.arrayUnion([userId]),
      });

      // Get updated session
      final updatedSession = await getSessionById(sessionId);
      return updatedSession;
    } catch (e, stackTrace) {
      _logger.e('Error joining session: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Ends a session
  Future<SessionModel> endSession(String sessionId) async {
    try {
      final sessionRef = _firestore
          .collection(FirestoreCollections.sessions)
          .doc(sessionId);

      final now = DateTime.now();

      // Update session status to ended
      await sessionRef.update({
        'status': SessionStatus.ended.toValue(),
        'ended_at': Timestamp.fromDate(now),
      });

      // Get updated session
      final updatedSession = await getSessionById(sessionId);
      return updatedSession;
    } catch (e, stackTrace) {
      _logger.e('Error ending session: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Gets active sessions
  Future<List<SessionModel>> getActiveSessions() async {
    try {
      final querySnapshot =
          await _firestore
              .collection(FirestoreCollections.sessions)
              .where('status', isEqualTo: SessionStatus.active.toValue())
              .orderBy('created_at', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => SessionModel.fromJson(doc.data()))
          .toList();
    } catch (e, stackTrace) {
      _logger.e(
        'Error getting active sessions: $e',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Gets sessions for a user
  Future<List<SessionModel>> getUserSessions(String userId) async {
    try {
      final querySnapshot =
          await _firestore
              .collection(FirestoreCollections.sessions)
              .where('speaker_id', isEqualTo: userId)
              .orderBy('created_at', descending: true)
              .get();

      return querySnapshot.docs
          .map((doc) => SessionModel.fromJson(doc.data()))
          .toList();
    } catch (e, stackTrace) {
      _logger.e(
        'Error getting user sessions: $e',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Leaves a session
  Future<void> leaveSession({
    required String sessionId,
    required String userId,
  }) async {
    try {
      final sessionRef = _firestore
          .collection(FirestoreCollections.sessions)
          .doc(sessionId);

      // Remove user from listeners list
      await sessionRef.update({
        'listeners': FieldValue.arrayRemove([userId]),
      });
    } catch (e, stackTrace) {
      _logger.e('Error leaving session: $e', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Checks if a session code already exists
  Future<bool> checkCodeExists(String code) async {
    try {
      final querySnapshot =
          await _firestore
              .collection(FirestoreCollections.sessions)
              .where('code', isEqualTo: code)
              .limit(1)
              .get();

      return querySnapshot.docs.isNotEmpty;
    } catch (e, stackTrace) {
      _logger.e(
        'Error checking if code exists: $e',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Streams updates for a session
  Stream<SessionModel> streamSession(String sessionId) {
    try {
      return _firestore
          .collection(FirestoreCollections.sessions)
          .doc(sessionId)
          .snapshots()
          .map((snapshot) {
            if (!snapshot.exists) {
              throw SessionNotFoundException();
            }
            return SessionModel.fromJson(snapshot.data()!);
          });
    } catch (e, stackTrace) {
      _logger.e(
        'Error streaming session: $e',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }
}
