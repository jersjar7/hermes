// lib/core/services/auth/auth_service_impl.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'auth_service.dart';
import 'auth_user.dart';

class AuthServiceImpl implements IAuthService {
  final FirebaseAuth _firebase = FirebaseAuth.instance;

  @override
  Future<AuthUser> signInAnonymously() async {
    final result = await _firebase.signInAnonymously();
    final user = result.user;
    if (user == null) throw Exception('Anonymous sign-in failed');
    return AuthUser(uid: user.uid, isAnonymous: user.isAnonymous);
  }

  @override
  Future<void> signOut() => _firebase.signOut();

  @override
  AuthUser? get currentUser {
    final user = _firebase.currentUser;
    if (user == null) return null;
    return AuthUser(uid: user.uid, isAnonymous: user.isAnonymous);
  }
}
