// lib/config/env.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:developer' as developer;

/// Environment configuration for the application
class Env {
  /// The base URL for the API
  static String get apiBaseUrl =>
      dotenv.env['API_BASE_URL'] ?? 'https://api.example.com';

  /// Firebase configuration
  static String get firebaseProjectId =>
      dotenv.env['FIREBASE_PROJECT_ID'] ?? '';

  /// Google Cloud API keys
  static String get googleCloudApiKey =>
      dotenv.env['GOOGLE_CLOUD_API_KEY'] ?? '';

  /// WebSocket URL for real-time communication
  static String get websocketUrl =>
      dotenv.env['WEBSOCKET_URL'] ?? 'wss://hermes-ws.example.com';

  /// Initialize environment variables
  static Future<void> init() async {
    await dotenv.load(fileName: '.env');

    // Now log the loaded values (be careful with sensitive values)
    developer.log(
      'Environment loaded: ${dotenv.env.keys.join(', ')}',
      name: 'Env',
    );
    developer.log('API Base URL: $apiBaseUrl', name: 'Env');
    developer.log(
      'Google Cloud API Key length: ${googleCloudApiKey.length}',
      name: 'Env',
    );
    developer.log('Firebase Project ID: $firebaseProjectId', name: 'Env');
    developer.log('WebSocket URL: $websocketUrl', name: 'Env');
    developer.log(
      'Environment mode: ${isDevelopment ? "development" : "production"}',
      name: 'Env',
    );
  }

  /// Determine if we're running in development mode
  static bool get isDevelopment => dotenv.env['ENVIRONMENT'] == 'development';

  /// Determine if we're running in production mode
  static bool get isProduction => dotenv.env['ENVIRONMENT'] == 'production';

  // Helper function to ensure string length safety
  int min(int a, int b) => a < b ? a : b;
}
