// lib/core/services/audio_player_service.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:injectable/injectable.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

/// Service to handle audio playback operations
@lazySingleton
class AudioPlayerService {
  final AudioPlayer _audioPlayer;
  StreamSubscription<PlayerState>? _playerStateSubscription;

  /// Creates a new [AudioPlayerService]
  AudioPlayerService(this._audioPlayer);

  /// Factory constructor with default AudioPlayer instance
  @factoryMethod
  static AudioPlayerService create() => AudioPlayerService(AudioPlayer());

  /// Initialize the audio player
  Future<void> init() async {
    _playerStateSubscription = _audioPlayer.playerStateStream.listen((state) {
      // Handle state changes
    });
  }

  /// Play audio from URL
  Future<void> playFromUrl(String url) async {
    await _audioPlayer.setUrl(url);
    await _audioPlayer.play();
  }

  /// Play audio from bytes
  Future<void> playFromBytes(Uint8List bytes) async {
    // Create a temporary file
    final tempDir = await getTemporaryDirectory();
    final tempPath =
        '${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.mp3';

    final file = File(tempPath);
    await file.writeAsBytes(bytes);

    await _audioPlayer.setFilePath(tempPath);
    await _audioPlayer.play();

    // Clean up after playback
    _audioPlayer.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        file.delete().catchError((_) => file);
      }
    });
  }

  /// Pause audio playback
  Future<void> pause() async {
    await _audioPlayer.pause();
  }

  /// Resume audio playback
  Future<void> resume() async {
    await _audioPlayer.play();
  }

  /// Stop audio playback
  Future<void> stop() async {
    await _audioPlayer.stop();
  }

  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    await _audioPlayer.setVolume(volume);
  }

  /// Get the current playback position
  Duration get position => _audioPlayer.position;

  /// Get the duration of the current audio
  Duration? get duration => _audioPlayer.duration;

  /// Stream of player state changes
  Stream<PlayerState> get playerStateStream => _audioPlayer.playerStateStream;

  /// Stream of playback positions
  Stream<Duration> get positionStream => _audioPlayer.positionStream;

  /// Clean up resources
  Future<void> dispose() async {
    await _playerStateSubscription?.cancel();
    await _audioPlayer.dispose();
  }
}
