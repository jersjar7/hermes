// lib/features/translation/infrastructure/services/stt/audio_stream_handler.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';

/// Handles streaming of audio data from the microphone
class AudioStreamHandler {
  final AudioRecorder _recorder;

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _isStreaming = false;
  bool _isPaused = false;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _amplitudeSubscription;
  DateTime? _startTime;
  Completer<bool>? _initializationCompleter;

  StreamController<Uint8List>? _audioStreamController;
  int _errorCount = 0; // Track consecutive errors for backoff

  /// Stream of audio data chunks
  Stream<Uint8List> get audioStream =>
      _audioStreamController?.stream ?? const Stream.empty();

  /// Whether currently streaming audio
  bool get isStreaming => _isStreaming;

  /// Whether streaming is paused
  bool get isPaused => _isPaused;

  /// Whether the handler is initialized
  bool get isInitialized => _isInitialized;

  /// Whether the handler is in the process of initializing
  bool get isInitializing => _isInitializing;

  /// Creates a new [AudioStreamHandler]
  AudioStreamHandler(this._recorder) {
    _startTime = DateTime.now();
    print("[AUDIO_HANDLER] AudioStreamHandler created");
  }

  /// Initialize the audio handler
  Future<bool> init() async {
    final elapsed =
        _startTime != null
            ? DateTime.now().difference(_startTime!).inMilliseconds
            : 0;

    print("[AUDIO_HANDLER] [+${elapsed}ms] init() called");

    if (_isInitialized) {
      print("[AUDIO_HANDLER] [+${elapsed}ms] Already initialized");
      return true;
    }

    if (_isInitializing) {
      print("[AUDIO_HANDLER] [+${elapsed}ms] Already initializing, waiting...");

      // If there's an active initialization, wait for it to complete
      if (_initializationCompleter != null &&
          !_initializationCompleter!.isCompleted) {
        return await _initializationCompleter!.future;
      }

      // Wait for initialization to complete with timeout
      final timeoutDuration = const Duration(seconds: 10);
      int attempts = 0;
      while (_isInitializing && attempts < 50) {
        await Future.delayed(const Duration(milliseconds: 200));
        attempts++;

        // Timeout after 10 seconds
        if (attempts * 200 > timeoutDuration.inMilliseconds) {
          print("[AUDIO_HANDLER] [+${elapsed}ms] Initialization timeout");
          _isInitializing = false;
          return false;
        }
      }
      return _isInitialized;
    }

    _isInitializing = true;
    _initializationCompleter = Completer<bool>();

    try {
      // Check if encoder is supported
      print("[AUDIO_HANDLER] [+${elapsed}ms] Checking encoder support");
      final isEncoderSupported = await _recorder.isEncoderSupported(
        AudioEncoder.pcm16bits,
      );

      if (!isEncoderSupported) {
        print(
          "[AUDIO_HANDLER] [+${elapsed}ms] PCM16 encoder not supported on this device",
        );
        _isInitializing = false;
        _initializationCompleter?.complete(false);
        return false;
      }

      print("[AUDIO_HANDLER] [+${elapsed}ms] Encoder supported");

      // Verify recorder can be initialized
      print("[AUDIO_HANDLER] [+${elapsed}ms] Checking recorder initialization");
      try {
        // Do a quick check on recorder availability
        if (await _recorder.isRecording()) {
          print(
            "[AUDIO_HANDLER] [+${elapsed}ms] Recorder is already recording, stopping first",
          );
          await _recorder.stop();

          // Add a small delay after stopping to ensure clean state
          await Future.delayed(const Duration(milliseconds: 500));
        }
        print("[AUDIO_HANDLER] [+${elapsed}ms] Recorder check complete");
      } catch (e) {
        print("[AUDIO_HANDLER] [+${elapsed}ms] Error checking recorder: $e");
        _isInitializing = false;
        _initializationCompleter?.complete(false);
        return false;
      }

      _isInitialized = true;
      _isInitializing = false;
      print(
        "[AUDIO_HANDLER] [+${elapsed}ms] Initialization completed successfully",
      );
      _initializationCompleter?.complete(true);
      return true;
    } catch (e) {
      print("[AUDIO_HANDLER] [+${elapsed}ms] Error during initialization: $e");
      _isInitializing = false;
      _initializationCompleter?.complete(false);
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

    print("[AUDIO_HANDLER] [+${elapsed}ms] startStreaming called");

    if (_isStreaming) {
      print(
        "[AUDIO_HANDLER] [+${elapsed}ms] Already streaming, stopping first",
      );
      await stopStreaming();

      // Add delay after stopping
      await Future.delayed(const Duration(milliseconds: 500));
    }

    // Ensure initialized
    if (!_isInitialized) {
      print(
        "[AUDIO_HANDLER] [+${elapsed}ms] Not initialized, initializing first",
      );
      final initialized = await init();
      if (!initialized) {
        print("[AUDIO_HANDLER] [+${elapsed}ms] Failed to initialize");
        return false;
      }
    }

    try {
      _isStreaming = true;
      _isPaused = false;

      // Check if already recording and stop if needed
      try {
        if (await _recorder.isRecording()) {
          print(
            "[AUDIO_HANDLER] [+${elapsed}ms] Already recording, stopping first",
          );
          await _recorder.stop();
          // Small delay after stopping to ensure clean state
          await Future.delayed(const Duration(milliseconds: 500));
        }
      } catch (e) {
        print(
          "[AUDIO_HANDLER] [+${elapsed}ms] Error checking recorder state: $e",
        );
        // Continue anyway, since we'll try to start recording
      }

      // Create a new stream controller if needed or closed
      if (_audioStreamController == null || _audioStreamController!.isClosed) {
        print(
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

      print(
        "[AUDIO_HANDLER] [+${elapsed}ms] Starting audio stream with config: $config",
      );

      // More robust error handling
      try {
        // Start recording stream
        final audioStream = await _recorder.startStream(config);
        print(
          "[AUDIO_HANDLER] [+${elapsed}ms] Recording stream started successfully",
        );

        // Reset error count on successful start
        _errorCount = 0;

        // Subscribe to the stream
        _audioSubscription = audioStream.listen(
          (data) {
            // More detailed logging (periodically)
            if (DateTime.now().millisecondsSinceEpoch % 5000 < 200) {
              print(
                "[AUDIO_HANDLER] Audio data received: ${data.length} bytes",
              );
            }

            if (_isStreaming &&
                !_isPaused &&
                _audioStreamController != null &&
                !_audioStreamController!.isClosed) {
              _audioStreamController!.add(data);
            }
          },
          onError: (error) {
            print("[AUDIO_HANDLER] Error in audio stream: $error");

            // Increment error count for backoff strategy
            _errorCount++;

            if (_audioStreamController != null &&
                !_audioStreamController!.isClosed) {
              _audioStreamController!.addError(error);
            }

            // If we get too many consecutive errors, stop and restart
            if (_errorCount > 5) {
              print("[AUDIO_HANDLER] Too many errors, restarting stream");
              stopStreaming().then((_) {
                // Restart with exponential backoff
                Future.delayed(Duration(milliseconds: 500 * _errorCount), () {
                  if (_isStreaming) {
                    startStreaming(
                      sampleRate: sampleRate,
                      numChannels: numChannels,
                    );
                  }
                });
              });
            }
          },
          onDone: () {
            print("[AUDIO_HANDLER] Audio stream finished");
          },
        );

        // Verify we actually got a subscription
        if (_audioSubscription == null) {
          print("[AUDIO_HANDLER] Failed to subscribe to audio stream");
          return false;
        }

        print(
          "[AUDIO_HANDLER] [+${elapsed}ms] Audio streaming started successfully",
        );
        return true;
      } catch (e) {
        print("[AUDIO_HANDLER] Failed to start audio stream: $e");
        rethrow; // Re-throw to be caught by outer try/catch
      }
    } catch (e, stackTrace) {
      print(
        "[AUDIO_HANDLER] [+${elapsed}ms] Failed to start streaming audio: $e\nStack trace: $stackTrace",
      );

      // Clean up in case of error
      try {
        await stopStreaming();
      } catch (cleanupError) {
        print(
          "[AUDIO_HANDLER] [+${elapsed}ms] Error during cleanup after failed start: $cleanupError",
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

    print("[AUDIO_HANDLER] [+${elapsed}ms] pauseStreaming called");

    if (!_isStreaming || _isPaused) return;

    try {
      _isPaused = true; // Set state first in case of error

      try {
        if (await _recorder.isRecording()) {
          await _recorder.pause();
          print("[AUDIO_HANDLER] [+${elapsed}ms] Recorder paused");
        } else {
          print(
            "[AUDIO_HANDLER] [+${elapsed}ms] Recorder not running, nothing to pause",
          );
        }
      } catch (e) {
        print(
          "[AUDIO_HANDLER] [+${elapsed}ms] Error during recorder pause: $e",
        );
        // State is already set to paused, so continue
      }
    } catch (e, stackTrace) {
      print(
        "[AUDIO_HANDLER] [+${elapsed}ms] Error pausing audio streaming: $e\nStack trace: $stackTrace",
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

    print("[AUDIO_HANDLER] [+${elapsed}ms] resumeStreaming called");

    if (!_isStreaming || !_isPaused) return;

    try {
      _isPaused = false; // Set state first in case of error

      try {
        await _recorder.resume();
        print("[AUDIO_HANDLER] [+${elapsed}ms] Recorder resumed");
      } catch (e) {
        print(
          "[AUDIO_HANDLER] [+${elapsed}ms] Error during recorder resume: $e",
        );
        // State is already set to not paused, so continue
      }
    } catch (e, stackTrace) {
      print(
        "[AUDIO_HANDLER] [+${elapsed}ms] Error resuming audio streaming: $e\nStack trace: $stackTrace",
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

    print("[AUDIO_HANDLER] [+${elapsed}ms] stopStreaming called");

    // Set state flags immediately to prevent concurrent operations
    bool wasStreaming = _isStreaming;
    _isStreaming = false;
    _isPaused = false;

    if (!wasStreaming) {
      print("[AUDIO_HANDLER] [+${elapsed}ms] Not streaming, nothing to stop");
      return;
    }

    try {
      // Cancel subscriptions first
      if (_audioSubscription != null) {
        try {
          await _audioSubscription?.cancel();
          print("[AUDIO_HANDLER] [+${elapsed}ms] Audio subscription canceled");
        } catch (e) {
          print("[AUDIO_HANDLER] Error cancelling audio subscription: $e");
        } finally {
          _audioSubscription = null;
        }
      }

      if (_amplitudeSubscription != null) {
        try {
          await _amplitudeSubscription?.cancel();
          print(
            "[AUDIO_HANDLER] [+${elapsed}ms] Amplitude subscription canceled",
          );
        } catch (e) {
          print("[AUDIO_HANDLER] Error cancelling amplitude subscription: $e");
        } finally {
          _amplitudeSubscription = null;
        }
      }

      // Stop recorder if recording
      try {
        // FIXED: Changed this to properly check recording status and handle errors
        bool isCurrentlyRecording = false;
        try {
          isCurrentlyRecording = await _recorder.isRecording();
        } catch (e) {
          print("[AUDIO_HANDLER] Error checking recording status: $e");
          // Assume it might be recording if we can't check
          isCurrentlyRecording = true;
        }

        if (isCurrentlyRecording) {
          print("[AUDIO_HANDLER] [+${elapsed}ms] Stopping recorder...");
          await _recorder.stop();
          print(
            "[AUDIO_HANDLER] [+${elapsed}ms] Recorder stopped successfully",
          );
        } else {
          print(
            "[AUDIO_HANDLER] [+${elapsed}ms] Recorder not running, nothing to stop",
          );
        }
      } catch (e) {
        print("[AUDIO_HANDLER] Error stopping recorder: $e");
        // FIXED: Force dispose recorder in case of error
        try {
          await _recorder.dispose();
          print(
            "[AUDIO_HANDLER] [+${elapsed}ms] Recorder disposed after error",
          );
        } catch (disposeError) {
          print("[AUDIO_HANDLER] Error disposing recorder: $disposeError");
        }
      }

      // Close the stream controller if it exists and isn't closed
      if (_audioStreamController != null && !_audioStreamController!.isClosed) {
        try {
          await _audioStreamController!.close();
          print(
            "[AUDIO_HANDLER] [+${elapsed}ms] Audio stream controller closed",
          );
        } catch (e) {
          print("[AUDIO_HANDLER] Error closing stream controller: $e");
        }
        _audioStreamController = null;
      }
    } catch (e, stackTrace) {
      print(
        "[AUDIO_HANDLER] [+${elapsed}ms] Error stopping audio streaming: $e\nStack trace: $stackTrace",
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

    print("[AUDIO_HANDLER] [+${elapsed}ms] dispose called");

    try {
      await stopStreaming();

      // FIXED: Added force disposal of recorder
      try {
        await _recorder.dispose();
        print("[AUDIO_HANDLER] [+${elapsed}ms] Recorder disposed");
      } catch (e) {
        print("[AUDIO_HANDLER] Error disposing recorder: $e");
      }

      // Clean up initialization completer if needed
      if (_initializationCompleter != null &&
          !_initializationCompleter!.isCompleted) {
        _initializationCompleter!.complete(false);
      }
    } catch (e) {
      print("[AUDIO_HANDLER] Error during dispose: $e");
    } finally {
      // Always reset state even if errors occur
      _isInitialized = false;
      _isInitializing = false;
      _isStreaming = false;
      _isPaused = false;
      print("[AUDIO_HANDLER] [+${elapsed}ms] AudioStreamHandler disposed");
    }
  }
}
