// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hermes/config/di.dart';
import 'package:hermes/config/env.dart';
import 'package:hermes/core/themes/app_theme.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/routes.dart';

/// Main entry point for the application
void main() async {
  // Ensure Flutter is initialized
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Load environment variables
  await Env.init();

  // Initialize Firebase
  await Firebase.initializeApp();

  // Configure dependency injection
  await configureDependencies();

  // Get the logger instance
  final logger = getIt<Logger>();
  logger.i('Application started');

  // Run the app
  runApp(const MyApp());
}

/// Root widget of the application
class MyApp extends StatelessWidget {
  /// Creates a new [MyApp] instance
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hermes',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRouter.generateRoute,
      supportedLocales: const [
        Locale('en', ''), // English
        Locale('es', ''), // Spanish
        Locale('fr', ''), // French
        Locale('de', ''), // German
        Locale('it', ''), // Italian
        Locale('pt', ''), // Portuguese
        Locale('ja', ''), // Japanese
        Locale('zh', ''), // Chinese
        Locale('ru', ''), // Russian
        Locale('ar', ''), // Arabic
      ],
      localizationsDelegates: const [
        // AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
