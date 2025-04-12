// lib/features/translation/infrastructure/repositories/transcription_firestore_handler.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dartz/dartz.dart';
import 'package:hermes/config/firebase_config.dart';
import 'package:hermes/core/errors/failure.dart';
import 'package:hermes/core/services/network_checker.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/infrastructure/models/transcript_model.dart';

/// Handles Firestore operations for transcription repository
class TranscriptionFirestoreHandler {
  final FirebaseFirestore _firestore;
  final NetworkChecker _networkChecker;
  final Logger _logger;

  // Track active stream subscriptions to prevent memory leaks
  final Map<String, StreamSubscription> _activeStreamSubscriptions = {};

  /// Creates a new [TranscriptionFirestoreHandler]
  TranscriptionFirestoreHandler(
    this._firestore,
    this._networkChecker,
    this._logger,
  );

  /// Save transcript to Firestore
  Future<Either<Failure, Transcript>> saveTranscript(
    Transcript transcript,
  ) async {
    _logger.d("[FIRESTORE_HANDLER] saveTranscript called");
    try {
      _logger.d("[FIRESTORE_HANDLER] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        _logger.d("[FIRESTORE_HANDLER] No network connection");
        return const Left(NetworkFailure());
      }

      // Convert domain entity to model
      _logger.d("[FIRESTORE_HANDLER] Converting domain entity to model");
      final transcriptModel = TranscriptModel.fromEntity(transcript);

      // Save to Firestore
      _logger.d(
        "[FIRESTORE_HANDLER] Saving to Firestore collection: ${FirestoreCollections.transcripts}",
      );

      try {
        await _firestore
            .collection(FirestoreCollections.transcripts)
            .doc(transcript.id)
            .set(transcriptModel.toJson());
        _logger.d("[FIRESTORE_HANDLER] Saved to Firestore");

        return Right(transcript);
      } catch (firestoreError) {
        _logger.e(
          "[FIRESTORE_HANDLER] Firestore save operation failed",
          error: firestoreError,
        );
        return Left(
          ServerFailure(message: 'Failed to save transcript: $firestoreError'),
        );
      }
    } catch (e, stacktrace) {
      _logger.d("[FIRESTORE_HANDLER] Exception in saveTranscript: $e");
      _logger.e('Failed to save transcript', error: e, stackTrace: stacktrace);
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Get all transcripts for a session
  Future<Either<Failure, List<Transcript>>> getSessionTranscripts(
    String sessionId,
  ) async {
    _logger.d(
      "[FIRESTORE_HANDLER] getSessionTranscripts called for sessionId=$sessionId",
    );
    try {
      _logger.d("[FIRESTORE_HANDLER] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        _logger.d("[FIRESTORE_HANDLER] No network connection");
        return const Left(NetworkFailure());
      }

      _logger.d("[FIRESTORE_HANDLER] Querying Firestore");

      try {
        final querySnapshot =
            await _firestore
                .collection(FirestoreCollections.transcripts)
                .where('session_id', isEqualTo: sessionId)
                .where('is_final', isEqualTo: true)
                .orderBy('timestamp')
                .get();

        _logger.d(
          "[FIRESTORE_HANDLER] Got ${querySnapshot.docs.length} documents from Firestore",
        );

        final transcripts =
            querySnapshot.docs
                .map((doc) => TranscriptModel.fromJson(doc.data()).toEntity())
                .toList();

        return Right(transcripts);
      } catch (firestoreError) {
        _logger.e(
          "[FIRESTORE_HANDLER] Firestore query operation failed",
          error: firestoreError,
        );
        return Left(
          ServerFailure(message: 'Failed to get transcripts: $firestoreError'),
        );
      }
    } catch (e, stacktrace) {
      _logger.d("[FIRESTORE_HANDLER] Exception in getSessionTranscripts: $e");
      _logger.e(
        'Failed to get session transcripts',
        error: e,
        stackTrace: stacktrace,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Get recent transcripts for a session with limit
  Future<Either<Failure, List<Transcript>>> getRecentTranscripts({
    required String sessionId,
    int limit = 20,
  }) async {
    _logger.d(
      "[FIRESTORE_HANDLER] getRecentTranscripts called for sessionId=$sessionId, limit=$limit",
    );
    try {
      _logger.d("[FIRESTORE_HANDLER] Checking network connection");
      if (!await _networkChecker.hasConnection()) {
        _logger.d("[FIRESTORE_HANDLER] No network connection");
        return const Left(NetworkFailure());
      }

      _logger.d("[FIRESTORE_HANDLER] Querying Firestore");

      try {
        final querySnapshot =
            await _firestore
                .collection(FirestoreCollections.transcripts)
                .where('session_id', isEqualTo: sessionId)
                .where('is_final', isEqualTo: true)
                .orderBy('timestamp', descending: true)
                .limit(limit)
                .get();

        _logger.d(
          "[FIRESTORE_HANDLER] Got ${querySnapshot.docs.length} documents from Firestore",
        );

        final transcripts =
            querySnapshot.docs
                .map((doc) => TranscriptModel.fromJson(doc.data()).toEntity())
                .toList();

        // Return in chronological order (oldest first)
        transcripts.sort((a, b) => a.timestamp.compareTo(b.timestamp));
        _logger.d(
          "[FIRESTORE_HANDLER] Sorted ${transcripts.length} transcripts",
        );

        return Right(transcripts);
      } catch (firestoreError) {
        _logger.e(
          "[FIRESTORE_HANDLER] Firestore query operation failed",
          error: firestoreError,
        );
        return Left(
          ServerFailure(
            message: 'Failed to get recent transcripts: $firestoreError',
          ),
        );
      }
    } catch (e, stacktrace) {
      _logger.d("[FIRESTORE_HANDLER] Exception in getRecentTranscripts: $e");
      _logger.e(
        'Failed to get recent transcripts',
        error: e,
        stackTrace: stacktrace,
      );
      return Left(ServerFailure(message: e.toString()));
    }
  }

  /// Stream transcripts for a session
  Stream<Either<Failure, List<Transcript>>> streamSessionTranscripts(
    String sessionId,
  ) {
    _logger.d(
      "[FIRESTORE_HANDLER] streamSessionTranscripts called for sessionId=$sessionId",
    );

    // Clean up any existing subscription for this session
    _cleanupExistingStreamSubscription(sessionId);

    try {
      _logger.d("[FIRESTORE_HANDLER] Setting up Firestore stream");

      // Create a controller we can control
      final streamController = StreamController<
        Either<Failure, List<Transcript>>
      >.broadcast(
        onCancel: () {
          _logger.d(
            "[FIRESTORE_HANDLER] Stream controller for session $sessionId canceled",
          );
          _cleanupExistingStreamSubscription(sessionId);
        },
      );

      // Set up the Firestore query
      final query = _firestore
          .collection(FirestoreCollections.transcripts)
          .where('session_id', isEqualTo: sessionId)
          .where('is_final', isEqualTo: true)
          .orderBy('timestamp');

      // Subscribe to the Firestore query
      final subscription = query.snapshots().listen(
        (snapshot) {
          _logger.d(
            "[FIRESTORE_HANDLER] Received snapshot with ${snapshot.docs.length} documents",
          );
          try {
            final transcripts =
                snapshot.docs
                    .map(
                      (doc) => TranscriptModel.fromJson(doc.data()).toEntity(),
                    )
                    .toList();
            _logger.d(
              "[FIRESTORE_HANDLER] Mapped ${transcripts.length} transcripts",
            );

            // Only add to stream if controller is still open
            if (!streamController.isClosed) {
              streamController.add(Right(transcripts));
            }
          } catch (e, stacktrace) {
            _logger.d("[FIRESTORE_HANDLER] Error parsing transcripts: $e");
            _logger.e(
              'Error parsing transcripts',
              error: e,
              stackTrace: stacktrace,
            );

            // Only add to stream if controller is still open
            if (!streamController.isClosed) {
              streamController.add(Left(ServerFailure(message: e.toString())));
            }
          }
        },
        onError: (error, stacktrace) {
          _logger.d("[FIRESTORE_HANDLER] Error in stream: $error");
          _logger.e(
            'Error streaming transcripts',
            error: error,
            stackTrace: stacktrace,
          );

          // Only add to stream if controller is still open
          if (!streamController.isClosed) {
            streamController.add(
              Left(ServerFailure(message: error.toString())),
            );
          }
        },
        onDone: () {
          _logger.d("[FIRESTORE_HANDLER] Firestore stream closed");

          // Clean up resources
          _cleanupExistingStreamSubscription(sessionId);
        },
      );

      // Store the subscription for later cleanup
      _activeStreamSubscriptions[sessionId] = subscription;

      // Return the stream from our controlled controller
      return streamController.stream;
    } catch (e, stacktrace) {
      _logger.d(
        "[FIRESTORE_HANDLER] Exception in streamSessionTranscripts: $e",
      );
      _logger.e(
        'Failed to stream session transcripts',
        error: e,
        stackTrace: stacktrace,
      );

      // Return a stream with just the error
      return Stream.value(Left(ServerFailure(message: e.toString())));
    }
  }

  /// Clean up existing stream subscription for a session
  void _cleanupExistingStreamSubscription(String sessionId) {
    if (_activeStreamSubscriptions.containsKey(sessionId)) {
      _logger.d(
        "[FIRESTORE_HANDLER] Cleaning up existing subscription for session $sessionId",
      );

      try {
        _activeStreamSubscriptions[sessionId]?.cancel();
      } catch (e) {
        _logger.e("[FIRESTORE_HANDLER] Error canceling subscription", error: e);
      } finally {
        _activeStreamSubscriptions.remove(sessionId);
      }
    }
  }

  /// Clean up all resources
  Future<void> dispose() async {
    _logger.d("[FIRESTORE_HANDLER] dispose called");

    // Cancel all active subscriptions
    for (final sessionId in _activeStreamSubscriptions.keys.toList()) {
      _cleanupExistingStreamSubscription(sessionId);
    }

    _activeStreamSubscriptions.clear();
  }
}
