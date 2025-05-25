// lib/core/services/auth/auth_user.dart
/// Represents a basic authenticated user.
class AuthUser {
  final String uid;
  final bool isAnonymous;

  AuthUser({required this.uid, required this.isAnonymous});

  @override
  String toString() => 'AuthUser(uid: $uid, isAnonymous: $isAnonymous)';
}
