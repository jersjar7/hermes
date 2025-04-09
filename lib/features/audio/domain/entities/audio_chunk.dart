// lib/features/audio/domain/entities/audio_chunk.dart

import 'dart:typed_data';
import 'package:equatable/equatable.dart';

/// Represents an audio chunk entity in the domain layer
class AudioChunk extends Equatable {
  /// Unique identifier for the audio chunk
  final String id;

  /// ID of the session this audio chunk belongs to
  final String sessionId;

  /// Raw audio data
  final Uint8List audioData;

  /// Audio format (e.g., 'audio/wav', 'audio/mp3')
  final String format;

  /// Sample rate in Hz
  final int sampleRate;

  /// Number of channels (e.g., 1 for mono, 2 for stereo)
  final int channels;

  /// Duration of the audio chunk in milliseconds
  final int durationMs;

  /// When the audio chunk was created
  final DateTime timestamp;

  /// Creates a new [AudioChunk] instance
  const AudioChunk({
    required this.id,
    required this.sessionId,
    required this.audioData,
    required this.format,
    required this.sampleRate,
    required this.channels,
    required this.durationMs,
    required this.timestamp,
  });

  /// Creates a copy of this audio chunk with the given fields replaced
  AudioChunk copyWith({
    String? id,
    String? sessionId,
    Uint8List? audioData,
    String? format,
    int? sampleRate,
    int? channels,
    int? durationMs,
    DateTime? timestamp,
  }) {
    return AudioChunk(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      audioData: audioData ?? this.audioData,
      format: format ?? this.format,
      sampleRate: sampleRate ?? this.sampleRate,
      channels: channels ?? this.channels,
      durationMs: durationMs ?? this.durationMs,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  List<Object?> get props => [
    id,
    sessionId,
    // Not including audioData in props comparison as it can be large
    format,
    sampleRate,
    channels,
    durationMs,
    timestamp,
  ];
}
