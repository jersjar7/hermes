// lib/features/translation/infrastructure/services/audio_stream_handler.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:hermes/core/utils/logger.dart';

/// Handles streaming of audio data from the Record package
class AudioStreamHandler {
  final AudioRecorder _recorder;
  final Logger _logger;

  bool _isStreaming = false;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _amplitudeSubscription;

  final StreamController<Uint8List> _audioStreamController =
      StreamController<Uint8List>.broadcast();

  /// Stream of audio data chunks
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  /// Creates a new [AudioStreamHandler]
  AudioStreamHandler(this._recorder, this._logger);

  /// Start streaming audio in chunks
  Future<bool> startStreaming({
    int sampleRate = 16000,
    int numChannels = 1,
  }) async {
    if (_isStreaming) {
      await stopStreaming();
    }

    try {
      _isStreaming = true;

      // Configure recording
      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits, // Raw PCM is best for STT
        sampleRate: sampleRate,
        numChannels: numChannels,
        autoGain: true, // Improve speech capture
        echoCancel: true, // Good for speech
        noiseSuppress: true, // Good for speech
      );

      // Start recording stream
      final audioStream = await _recorder.startStream(config);

      // Subscribe to the stream
      _audioSubscription = audioStream.listen(
        (data) {
          if (_isStreaming) {
            _audioStreamController.add(data);
          }
        },
        onError: (error) {
          _logger.e('Error in audio stream', error: error);
          _audioStreamController.addError(error);
        },
        onDone: () {
          _logger.d('Audio stream done');
        },
      );

      // Monitor amplitude for debugging (optional)
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 100))
          .listen((amp) {
            // You can log amplitude for debugging or UI feedback
            // _logger.d('Amplitude: ${amp.current}, Max: ${amp.max}');
          });

      return true;
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to start streaming audio',
        error: e,
        stackTrace: stackTrace,
      );
      await stopStreaming();
      return false;
    }
  }

  /// Pause streaming
  Future<void> pauseStreaming() async {
    if (!_isStreaming) return;

    try {
      await _recorder.pause();
    } catch (e, stackTrace) {
      _logger.e(
        'Error pausing audio streaming',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Resume streaming
  Future<void> resumeStreaming() async {
    if (!_isStreaming) return;

    try {
      await _recorder.resume();
    } catch (e, stackTrace) {
      _logger.e(
        'Error resuming audio streaming',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Stop streaming
  Future<void> stopStreaming() async {
    _isStreaming = false;

    try {
      await _audioSubscription?.cancel();
      await _amplitudeSubscription?.cancel();

      _audioSubscription = null;
      _amplitudeSubscription = null;

      await _recorder.stop();
    } catch (e, stackTrace) {
      _logger.e(
        'Error stopping audio streaming',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Check if streaming is active
  bool get isStreaming => _isStreaming;

  /// Dispose resources
  Future<void> dispose() async {
    await stopStreaming();
    await _audioStreamController.close();
  }
}
