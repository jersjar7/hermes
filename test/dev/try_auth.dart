// lib/dev/try_auth.dart
import 'package:flutter/widgets.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/auth/auth_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(); // ✅ Init FIRST
  await setupServiceLocator(); // ✅ Register DI SECOND

  final auth = getIt<IAuthService>();

  final user = await auth.signInAnonymously();
  print('✅ Signed in anonymously: $user');

  await Future.delayed(Duration(seconds: 2));
  await auth.signOut();
  print('👋 Signed out');
}
