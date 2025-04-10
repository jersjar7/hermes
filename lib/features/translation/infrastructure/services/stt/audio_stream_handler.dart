// lib/features/translation/infrastructure/services/stt/audio_stream_handler.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:record/record.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/translation/infrastructure/services/stt/stt_exceptions.dart';

/// Handles streaming of audio data from the microphone
class AudioStreamHandler {
  final AudioRecorder _recorder;
  final Logger _logger;

  bool _isStreaming = false;
  bool _isPaused = false;
  StreamSubscription? _audioSubscription;
  StreamSubscription? _amplitudeSubscription;

  final StreamController<Uint8List> _audioStreamController =
      StreamController<Uint8List>.broadcast();

  /// Stream of audio data chunks
  Stream<Uint8List> get audioStream => _audioStreamController.stream;

  /// Whether currently streaming audio
  bool get isStreaming => _isStreaming;

  /// Whether streaming is paused
  bool get isPaused => _isPaused;

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
      _isPaused = false;

      // Check if encoder is supported
      final isEncoderSupported = await _recorder.isEncoderSupported(
        AudioEncoder.pcm16bits,
      );

      if (!isEncoderSupported) {
        throw AudioProcessingException(
          'PCM16 encoder not supported on this device',
        );
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

      _logger.d('Starting audio recording with config: $config');

      // Start recording stream
      final audioStream = await _recorder.startStream(config);

      // Subscribe to the stream
      _audioSubscription = audioStream.listen(
        (data) {
          if (_isStreaming && !_isPaused) {
            _audioStreamController.add(data);

            // Add more detailed audio data logging
            _logger.d(
              'Audio data received: ${data.length} bytes, first few bytes: ${data.take(10).toList()}',
            );

            // Add amplitude logging on each data chunk
            _recorder.getAmplitude().then((amp) {
              _logger.d('Current amplitude: ${amp.current}, Max: ${amp.max}');
            });
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

      // Monitor amplitude for debugging
      _amplitudeSubscription = _recorder
          .onAmplitudeChanged(const Duration(milliseconds: 300))
          .listen((amp) {
            _logger.d('Amplitude: ${amp.current}, Max: ${amp.max}');
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
    if (!_isStreaming || _isPaused) return;

    try {
      _isPaused = true;
      await _recorder.pause();
      _logger.d('Audio streaming paused');
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
    if (!_isStreaming || !_isPaused) return;

    try {
      _isPaused = false;
      await _recorder.resume();
      _logger.d('Audio streaming resumed');
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
    _isPaused = false;

    try {
      await _audioSubscription?.cancel();
      await _amplitudeSubscription?.cancel();

      _audioSubscription = null;
      _amplitudeSubscription = null;

      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }
      _logger.d('Audio streaming stopped');
    } catch (e, stackTrace) {
      _logger.e(
        'Error stopping audio streaming',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  /// Dispose resources
  Future<void> dispose() async {
    await stopStreaming();
    await _audioStreamController.close();
    _logger.d('AudioStreamHandler disposed');
  }
}
