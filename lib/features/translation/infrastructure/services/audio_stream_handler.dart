// lib/features/translation/infrastructure/services/audio_stream_handler.dart

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:hermes/core/utils/logger.dart';

/// Handles streaming of audio data from the Record package
class AudioStreamHandler {
  final Record _recorder;
  final Logger _logger;

  bool _isStreaming = false;
  String? _currentRecordingPath;
  Timer? _chunkTimer;
  int _lastReadPosition = 0;

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

      // Create a temporary file for recording
      final tempDir = await getTemporaryDirectory();
      _currentRecordingPath =
          '${tempDir.path}/hermes_recording_${DateTime.now().millisecondsSinceEpoch}.pcm';

      // Configure recording
      final config = RecordConfig(
        encoder: AudioEncoder.pcm16bits, // Raw PCM is best for STT
        sampleRate: sampleRate,
        numChannels: numChannels,
        autoGain: true, // Improve speech capture
        echoCancel: true, // Good for speech
        noiseSuppress: true, // Good for speech
      );

      // Start recording
      await _recorder.start(config: config, path: _currentRecordingPath);

      // Set up a timer to periodically read chunks from the recording file
      _lastReadPosition = 0;
      _chunkTimer = Timer.periodic(
        const Duration(milliseconds: 200), // 200ms chunks
        (_) => _readAudioChunk(),
      );

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

  /// Read a chunk of audio data from the current recording
  Future<void> _readAudioChunk() async {
    if (!_isStreaming || _currentRecordingPath == null) return;

    try {
      final file = File(_currentRecordingPath!);
      if (await file.exists()) {
        final fileLength = await file.length();

        // Only process if there's new data
        if (fileLength > _lastReadPosition) {
          final randomAccessFile = await file.open(mode: FileMode.read);
          await randomAccessFile.setPosition(_lastReadPosition);

          // Read new data
          final newData = await randomAccessFile.read(
            fileLength - _lastReadPosition,
          );
          await randomAccessFile.close();

          // Update position
          _lastReadPosition = fileLength;

          // Add data to stream if not empty
          if (newData.isNotEmpty) {
            _audioStreamController.add(Uint8List.fromList(newData));
          }
        }
      }
    } catch (e, stackTrace) {
      _logger.e('Error reading audio chunk', error: e, stackTrace: stackTrace);
    }
  }

  /// Pause streaming
  Future<void> pauseStreaming() async {
    if (!_isStreaming) return;

    try {
      if (_recorder.isRecording()) {
        await _recorder.pause();
        _chunkTimer?.cancel();
      }
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
      if (_recorder.isPaused()) {
        await _recorder.resume();

        // Restart chunk reading
        _chunkTimer = Timer.periodic(
          const Duration(milliseconds: 200),
          (_) => _readAudioChunk(),
        );
      }
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
      _chunkTimer?.cancel();
      _chunkTimer = null;

      if (_recorder.isRecording() || _recorder.isPaused()) {
        await _recorder.stop();
      }

      // Clean up recording file
      if (_currentRecordingPath != null) {
        final file = File(_currentRecordingPath!);
        if (await file.exists()) {
          try {
            await file.delete();
          } catch (e) {
            _logger.e('Error deleting temporary recording file', error: e);
          }
        }
        _currentRecordingPath = null;
      }

      _lastReadPosition = 0;
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
