// lib/features/translation/infrastructure/services/stt/stt_initializer.dart

import 'package:record/record.dart';
import 'package:hermes/config/env.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/audio_stream_handler.dart';

/// Handles initialization of the STT service
class SttInitializer {
  final Logger _logger;
  final AudioRecorder _recorder;

  bool _isInitializing = false;
  int _initializeAttempts = 0;
  DateTime? _startTime;

  /// Creates a new [SttInitializer]
  SttInitializer(this._logger, this._recorder) {
    _startTime = DateTime.now();
  }

  /// Whether initialization is in progress
  bool get isInitializing => _isInitializing;

  /// Initialize the service
  Future<bool> initialize(AudioStreamHandler audioHandler) async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d(
      "[STT_INIT] [+${elapsed}ms] initialize() called, _isInitializing=$_isInitializing",
    );

    // Prevent concurrent initialization
    if (_isInitializing) {
      _logger.d(
        "[STT_INIT] [+${elapsed}ms] init() already in progress, waiting...",
      );

      // Wait for initialization to complete
      int attempts = 0;
      while (_isInitializing && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }

      _logger.d(
        "[STT_INIT] [+${elapsed}ms] Waited for initialization, returning result",
      );
      return !_isInitializing; // If still initializing after waiting, return false
    }

    _isInitializing = true;
    _initializeAttempts++;

    try {
      _logger.d(
        "[STT_INIT] [+${elapsed}ms] Starting initialization (attempt #$_initializeAttempts)",
      );

      // Check API key
      final apiKey = Env.googleCloudApiKey;
      if (apiKey.isEmpty) {
        _logger.e('[STT_INIT] [+${elapsed}ms] Google Cloud API key is empty');
        _isInitializing = false;
        return false;
      } else {
        _logger.d(
          '[STT_INIT] [+${elapsed}ms] API key found: ${apiKey.substring(0, min(5, apiKey.length))}...(truncated)',
        );
      }

      // Check Firebase project ID
      final projectId = Env.firebaseProjectId;
      if (projectId.isEmpty) {
        _logger.e('[STT_INIT] [+${elapsed}ms] Firebase project ID is empty');
        _isInitializing = false;
        return false;
      } else {
        _logger.d('[STT_INIT] [+${elapsed}ms] Project ID found: $projectId');
      }

      // Check recorder availability - this is critical
      _logger.d('[STT_INIT] [+${elapsed}ms] Checking recorder support...');
      final isAvailable = await _recorder.isEncoderSupported(
        AudioEncoder.pcm16bits,
      );

      if (!isAvailable) {
        _logger.e(
          '[STT_INIT] [+${elapsed}ms] Recorder not available or encoder not supported',
        );
        _isInitializing = false;
        return false;
      } else {
        _logger.d(
          '[STT_INIT] [+${elapsed}ms] Audio recorder and encoder are available',
        );
      }

      // Check if .env file was loaded correctly
      _logger.d(
        '[STT_INIT] [+${elapsed}ms] Environment variables: API_BASE_URL=${Env.apiBaseUrl}',
      );

      // Initialize audio handler
      _logger.d('[STT_INIT] [+${elapsed}ms] Initializing audio handler');
      await audioHandler.init();
      _logger.d('[STT_INIT] [+${elapsed}ms] Audio handler initialized');

      _logger.d("[STT_INIT] [+${elapsed}ms] Service successfully initialized");
      return true;
    } catch (e, stacktrace) {
      _logger.e(
        'Failed to initialize STT service',
        error: e,
        stackTrace: stacktrace,
      );
      _logger.d("[STT_INIT] [+${elapsed}ms] Exception in init(): $e");
      _logger.d("[STT_INIT] [+${elapsed}ms] Stack trace: $stacktrace");
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  // Helper function
  int min(int a, int b) => a < b ? a : b;
}
