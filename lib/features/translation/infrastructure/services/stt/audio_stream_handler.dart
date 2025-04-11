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

  final StreamController<Uint8List> _audioStreamController =
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
      if (await _recorder.isRecording()) {
        _logger.d(
          "[AUDIO_HANDLER] [+${elapsed}ms] Already recording, stopping first",
        );
        await _recorder.stop();
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

      // Start recording stream
      final audioStream = await _recorder.startStream(config);
      _logger.d(
        "[AUDIO_HANDLER] [+${elapsed}ms] Recording stream started successfully",
      );

      // Subscribe to the stream
      _audioSubscription = audioStream.listen(
        (data) {
          if (_isStreaming && !_isPaused) {
            if (!_audioStreamController.isClosed) {
              _audioStreamController.add(data);
            }

            // Log data occasionally but not for every chunk to avoid excessive logging
            if (DateTime.now().millisecondsSinceEpoch % 1000 < 200) {
              // Log ~20% of chunks
              _logger.d(
                "[AUDIO_HANDLER] Audio data: ${data.length} bytes, first few bytes: ${data.take(4).toList()}",
              );
            }
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

      // Monitor amplitude for debugging
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 300))
          .listen((amp) {
            if (DateTime.now().millisecondsSinceEpoch % 3000 < 300) {
              // Log less frequently
              _logger.d(
                "[AUDIO_HANDLER] Amplitude: ${amp.current}, Max: ${amp.max}",
              );
            }
          });

      _logger.d(
        "[AUDIO_HANDLER] [+${elapsed}ms] Audio streaming started successfully",
      );
      return true;
    } catch (e, stackTrace) {
      _logger.e(
        "[AUDIO_HANDLER] [+${elapsed}ms] Failed to start streaming audio",
        error: e,
        stackTrace: stackTrace,
      );
      await stopStreaming();
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
      _isPaused = true;
      if (await _recorder.isRecording()) {
        await _recorder.pause();
        _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] Recorder paused");
      } else {
        _logger.d(
          "[AUDIO_HANDLER] [+${elapsed}ms] Recorder not running, nothing to pause",
        );
      }
    } catch (e, stackTrace) {
      _logger.e(
        "[AUDIO_HANDLER] [+${elapsed}ms] Error pausing audio streaming",
        error: e,
        stackTrace: stackTrace,
      );
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
      _isPaused = false;
      await _recorder.resume();
      _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] Recorder resumed");
    } catch (e, stackTrace) {
      _logger.e(
        "[AUDIO_HANDLER] [+${elapsed}ms] Error resuming audio streaming",
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Stop streaming
  Future<void> stopStreaming() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] stopStreaming called");

    _isStreaming = false;
    _isPaused = false;

    try {
      // Cancel subscriptions first
      await _audioSubscription?.cancel();
      _audioSubscription = null;

      await _amplitudeSubscription?.cancel();
      _amplitudeSubscription = null;
      _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] Audio subscriptions canceled");

      // Stop recorder if recording
      if (await _recorder.isRecording()) {
        await _recorder.stop();
        _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] Recorder stopped");
      } else {
        _logger.d(
          "[AUDIO_HANDLER] [+${elapsed}ms] Recorder not running, nothing to stop",
        );
      }
    } catch (e, stackTrace) {
      _logger.e(
        "[AUDIO_HANDLER] [+${elapsed}ms] Error stopping audio streaming",
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] dispose called");

    await stopStreaming();

    // Close stream controller if not already closed
    if (!_audioStreamController.isClosed) {
      await _audioStreamController.close();
      _logger.d(
        "[AUDIO_HANDLER] [+${elapsed}ms] Audio stream controller closed",
      );
    }

    _isInitialized = false;
    _logger.d("[AUDIO_HANDLER] [+${elapsed}ms] AudioStreamHandler disposed");
  }
}
