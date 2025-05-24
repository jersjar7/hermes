import 'auth_user.dart';

abstract class IAuthService {
  /// Logs in anonymously and returns a user object.
  Future<AuthUser> signInAnonymously();

  /// Signs out the current user.
  Future<void> signOut();

  /// Returns the currently signed-in user, or null if not signed in.
  AuthUser? get currentUser;
}
