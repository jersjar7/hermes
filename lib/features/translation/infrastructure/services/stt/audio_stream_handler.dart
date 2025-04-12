// lib/features/translation/infrastructure/services/stt/audio_stream_handler.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:hermes/core/utils/logger.dart';

/// Handles streaming of audio data from the microphone
class AudioStreamHandler {
  final AudioRecorder _recorder;
  final Logger _logger;

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isStreaming = false;
  bool _isPaused = false;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _amplitudeSubscription;
  DateTime? _startTime;

  StreamController<Uint8List> _audioStreamController =
      StreamController<Uint8List>.broadcast();

  /// Stream of audio data chunks
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  /// Whether currently streaming audio
  bool get isStreaming => _isStreaming;

  /// Whether streaming is paused
  bool get isPaused => _isPaused;

  /// Whether the handler is initialized
  bool get isInitialized => _isInitialized;

  /// Whether the handler is in the process of initializing
  bool get isInitializing => _isInitializing;

  /// Creates a new [AudioStreamHandler]
  AudioStreamHandler(this._recorder, this._logger) {
    _startTime = DateTime.now();
    _logger.d("[AUDIO_HANDLER] AudioStreamHandler created");
    // ADDED: Initialize stream controller if not already done
    _audioStreamController = StreamController<Uint8List>.broadcast();
  }

  /// Initialize the audio handler
  Future<bool> init() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] init() called");

    if (_isInitialized) {
      _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] Already initialized");
      return true;
    }

    if (_isInitializing) {
      _logger.d(
        "[AUDIO_HANDLER] [+${elapsed}ms] Already initializing, waiting...",
      );
      // Wait for initialization to complete
      int attempts = 0;
      while (_isInitializing && attempts < 10) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;
      }
      return _isInitialized;
    }

    _isInitializing = true;

    try {
      // Check if encoder is supported
      _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] Checking encoder support");
      final isEncoderSupported = await _recorder.isEncoderSupported(
        AudioEncoder.pcm16bits,
      );

      if (!isEncoderSupported) {
        _logger.e(
          "[AUDIO_HANDLER] [+${elapsed}ms] PCM16 encoder not supported on this device",
        );
        _isInitializing = false;
        return false;
      }

      _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] Encoder supported");

      // Verify recorder can be initialized
      _logger.d(
        "[AUDIO_HANDLER] [+${elapsed}ms] Checking recorder initialization",
      );
      try {
        // Do a quick check on recorder availability
        if (await _recorder.isRecording()) {
          _logger.d(
            "[AUDIO_HANDLER] [+${elapsed}ms] Recorder is already recording, stopping first",
          );
          await _recorder.stop();
        }
        _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] Recorder check complete");
      } catch (e) {
        _logger.e(
          "[AUDIO_HANDLER] [+${elapsed}ms] Error checking recorder",
          error: e,
        );
        _isInitializing = false;
        return false;
      }

      _isInitialized = true;
      _isInitializing = false;
      _logger.d(
        "[AUDIO_HANDLER] [+${elapsed}ms] Initialization completed successfully",
      );
      return true;
    } catch (e) {
      _logger.e(
        "[AUDIO_HANDLER] [+${elapsed}ms] Error during initialization",
        error: e,
      );
      _isInitializing = false;
      return false;
    }
  }

  /// Start streaming audio in chunks
  Future<bool> startStreaming({
    int sampleRate = 16000,
    int numChannels = 1,
  }) async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] startStreaming called");

    if (_isStreaming) {
      _logger.d(
        "[AUDIO_HANDLER] [+${elapsed}ms] Already streaming, stopping first",
      );
      await stopStreaming();
    }

    // Ensure initialized
    if (!_isInitialized) {
      _logger.d(
        "[AUDIO_HANDLER] [+${elapsed}ms] Not initialized, initializing first",
      );
      final initialized = await init();
      if (!initialized) {
        _logger.e("[AUDIO_HANDLER] [+${elapsed}ms] Failed to initialize");
        return false;
      }
    }

    try {
      _isStreaming = true;
      _isPaused = false;

      // Check if already recording and stop if needed
      try {
        if (await _recorder.isRecording()) {
          _logger.d(
            "[AUDIO_HANDLER] [+${elapsed}ms] Already recording, stopping first",
          );
          await _recorder.stop();
          // ADDED: Small delay after stopping to ensure clean state
          await Future.delayed(const Duration(milliseconds: 100));
        }
      } catch (e) {
        _logger.e(
          "[AUDIO_HANDLER] [+${elapsed}ms] Error checking recorder state",
          error: e,
        );
        // Continue anyway, since we'll try to start recording
      }

      // CHANGED: Create a new stream controller if needed or closed
      if (_audioStreamController.isClosed) {
        _logger.d(
          "[AUDIO_HANDLER] [+${elapsed}ms] Creating new audio stream controller",
        );
        _audioStreamController = StreamController<Uint8List>.broadcast();
      }

      // Configure recording
      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits, // Raw PCM is best for STT
        sampleRate: sampleRate,
        numChannels: numChannels,
        autoGain: true, // Improve speech capture
        echoCancel: true, // Good for speech
        noiseSuppress: true, // Good for speech
      );

      _logger.d(
        "[AUDIO_HANDLER] [+${elapsed}ms] Starting audio stream with config: $config",
      );

      // CHANGED: More robust error handling
      try {
        // Start recording stream
        final audioStream = await _recorder.startStream(config);
        _logger.d(
          "[AUDIO_HANDLER] [+${elapsed}ms] Recording stream started successfully",
        );

        // Subscribe to the stream
        _audioSubscription = audioStream.listen(
          (data) {
            // ADDED: More detailed logging
            if (DateTime.now().millisecondsSinceEpoch % 3000 < 200) {
              // Log ~6% of chunks
              _logger.d(
                "[AUDIO_HANDLER] Audio data received: ${data.length} bytes",
              );
            }

            if (_isStreaming &&
                !_isPaused &&
                !_audioStreamController.isClosed) {
              _audioStreamController.add(data);
            }
          },
          onError: (error) {
            _logger.e("[AUDIO_HANDLER] Error in audio stream", error: error);
            if (!_audioStreamController.isClosed) {
              _audioStreamController.addError(error);
            }
          },
          onDone: () {
            _logger.d("[AUDIO_HANDLER] Audio stream finished");
          },
        );

        // ADDED: Verify we actually got a subscription
        if (_audioSubscription == null) {
          _logger.e("[AUDIO_HANDLER] Failed to subscribe to audio stream");
          return false;
        }

        _logger.d(
          "[AUDIO_HANDLER] [+${elapsed}ms] Audio streaming started successfully",
        );
        return true;
      } catch (e) {
        _logger.e("[AUDIO_HANDLER] Failed to start audio stream", error: e);
        rethrow; // Re-throw to be caught by outer try/catch
      }
    } catch (e, stackTrace) {
      _logger.e(
        "[AUDIO_HANDLER] [+${elapsed}ms] Failed to start streaming audio",
        error: e,
        stackTrace: stackTrace,
      );

      // Clean up in case of error
      try {
        await stopStreaming();
      } catch (cleanupError) {
        _logger.e(
          "[AUDIO_HANDLER] [+${elapsed}ms] Error during cleanup after failed start",
          error: cleanupError,
        );
      }

      // Ensure state is reset regardless of cleanup success
      _isStreaming = false;
      _isPaused = false;
      return false;
    }
  }

  /// Pause streaming
  Future<void> pauseStreaming() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] pauseStreaming called");

    if (!_isStreaming || _isPaused) return;

    try {
      _isPaused = true; // Set state first in case of error

      try {
        if (await _recorder.isRecording()) {
          await _recorder.pause();
          _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] Recorder paused");
        } else {
          _logger.d(
            "[AUDIO_HANDLER] [+${elapsed}ms] Recorder not running, nothing to pause",
          );
        }
      } catch (e) {
        _logger.e(
          "[AUDIO_HANDLER] [+${elapsed}ms] Error during recorder pause",
          error: e,
        );
        // State is already set to paused, so continue
      }
    } catch (e, stackTrace) {
      _logger.e(
        "[AUDIO_HANDLER] [+${elapsed}ms] Error pausing audio streaming",
        error: e,
        stackTrace: stackTrace,
      );
      // Ensure state is correctly set even after error
      _isPaused = true;
    }
  }

  /// Resume streaming
  Future<void> resumeStreaming() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] resumeStreaming called");

    if (!_isStreaming || !_isPaused) return;

    try {
      _isPaused = false; // Set state first in case of error

      try {
        await _recorder.resume();
        _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] Recorder resumed");
      } catch (e) {
        _logger.e(
          "[AUDIO_HANDLER] [+${elapsed}ms] Error during recorder resume",
          error: e,
        );
        // State is already set to not paused, so continue
      }
    } catch (e, stackTrace) {
      _logger.e(
        "[AUDIO_HANDLER] [+${elapsed}ms] Error resuming audio streaming",
        error: e,
        stackTrace: stackTrace,
      );
      // Ensure state is correctly set even after error
      _isPaused = false;
    }
  }

  /// Stop streaming
  Future<void> stopStreaming() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] stopStreaming called");

    // Set state flags immediately to prevent concurrent operations
    bool wasStreaming = _isStreaming;
    _isStreaming = false;
    _isPaused = false;

    if (!wasStreaming) {
      _logger.d(
        "[AUDIO_HANDLER] [+${elapsed}ms] Not streaming, nothing to stop",
      );
      return;
    }

    try {
      // Cancel subscriptions first
      if (_audioSubscription != null) {
        try {
          await _audioSubscription?.cancel();
          _logger.d(
            "[AUDIO_HANDLER] [+${elapsed}ms] Audio subscription canceled",
          );
        } catch (e) {
          _logger.e(
            "[AUDIO_HANDLER] Error cancelling audio subscription",
            error: e,
          );
        } finally {
          _audioSubscription = null;
        }
      }

      if (_amplitudeSubscription != null) {
        try {
          await _amplitudeSubscription?.cancel();
          _logger.d(
            "[AUDIO_HANDLER] [+${elapsed}ms] Amplitude subscription canceled",
          );
        } catch (e) {
          _logger.e(
            "[AUDIO_HANDLER] Error cancelling amplitude subscription",
            error: e,
          );
        } finally {
          _amplitudeSubscription = null;
        }
      }

      // Stop recorder if recording
      try {
        if (await _recorder.isRecording()) {
          await _recorder.stop();
          _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] Recorder stopped");
        } else {
          _logger.d(
            "[AUDIO_HANDLER] [+${elapsed}ms] Recorder not running, nothing to stop",
          );
        }
      } catch (e) {
        _logger.e("[AUDIO_HANDLER] Error stopping recorder", error: e);
        // Continue regardless
      }
    } catch (e, stackTrace) {
      _logger.e(
        "[AUDIO_HANDLER] [+${elapsed}ms] Error stopping audio streaming",
        error: e,
        stackTrace: stackTrace,
      );
    } finally {
      // Ensure all state is reset properly
      _isStreaming = false;
      _isPaused = false;
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] dispose called");

    try {
      await stopStreaming();

      // Close stream controller if not already closed
      if (!_audioStreamController.isClosed) {
        try {
          await _audioStreamController.close();
          _logger.d(
            "[AUDIO_HANDLER] [+${elapsed}ms] Audio stream controller closed",
          );
        } catch (e) {
          _logger.e(
            "[AUDIO_HANDLER] Error closing stream controller",
            error: e,
          );
        }
      } else {
        _logger.d("[AUDIO_HANDLER] Stream controller already closed");
      }
    } catch (e) {
      _logger.e("[AUDIO_HANDLER] Error during dispose", error: e);
    } finally {
      // Always reset state even if errors occur
      _isInitialized = false;
      _isInitializing = false;
      _isStreaming = false;
      _isPaused = false;
      _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] AudioStreamHandler disposed");
    }
  }
}
