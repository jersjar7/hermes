// lib/features/session/infrastructure/services/auth_service.dart

import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:injectable/injectable.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/session/domain/entities/user.dart' as domain;

/// Authentication service for Firebase
@lazySingleton
class AuthService {
  final FirebaseAuth _auth;
  final Logger _logger;

  /// Creates a new [AuthService]
  AuthService(this._auth, this._logger);

  /// Get current user
  domain.User? get currentUser {
    final firebaseUser = _auth.currentUser;

    if (firebaseUser == null) {
      return null;
    }

    return domain.User(
      id: firebaseUser.uid,
      name: firebaseUser.displayName,
      role: domain.UserRole.audience, // Default role
      preferredLanguage: 'en', // Default language
      createdAt: DateTime.now(),
    );
  }

  /// Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  /// Sign in anonymously
  Future<domain.User> signInAnonymously() async {
    try {
      final result = await _auth.signInAnonymously();
      final firebaseUser = result.user;

      if (firebaseUser == null) {
        throw Exception('Failed to sign in anonymously');
      }

      return domain.User(
        id: firebaseUser.uid,
        role: domain.UserRole.audience,
        preferredLanguage: 'en', // Default to English
        createdAt: DateTime.now(),
      );
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to sign in anonymously',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e, stackTrace) {
      _logger.e('Failed to sign out', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Get user ID
  String? get userId => _auth.currentUser?.uid;

  /// Update user role
  Future<domain.User> updateUserRole(domain.UserRole role) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('User not signed in');
    }

    // In a real app, you would update this in a user profile database
    // This implementation just returns a new user object with the updated role
    return user.copyWith(role: role);
  }

  /// Update user preferred language
  Future<domain.User> updatePreferredLanguage(String languageCode) async {
    final user = currentUser;

    if (user == null) {
      throw Exception('User not signed in');
    }

    // In a real app, you would update this in a user profile database
    // This implementation just returns a new user object with the updated language
    return user.copyWith(preferredLanguage: languageCode);
  }

  /// Stream of auth state changes
  Stream<domain.User?> get authStateChanges {
    return _auth.authStateChanges().map((firebaseUser) {
      if (firebaseUser == null) {
        return null;
      }

      return domain.User(
        id: firebaseUser.uid,
        name: firebaseUser.displayName,
        role: domain.UserRole.audience, // Default role
        preferredLanguage: 'en', // Default language
        createdAt: DateTime.now(),
      );
    });
  }
}
