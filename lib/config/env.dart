// lib/config/env.dart

import 'package:flutter_dotenv/flutter_dotenv.dart';

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
  }

  /// Determine if we're running in development mode
  static bool get isDevelopment => dotenv.env['ENVIRONMENT'] == 'development';

  /// Determine if we're running in production mode
  static bool get isProduction => dotenv.env['ENVIRONMENT'] == 'production';
}
