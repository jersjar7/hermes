// lib/features/session/presentation/utils/transcript_message.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';

/// Data model for transcript messages with utility functions
class TranscriptMessage {
  final String text;
  final DateTime timestamp;

  const TranscriptMessage({required this.text, required this.timestamp});

  /// Creates a copy with optional overrides
  TranscriptMessage copyWith({String? text, DateTime? timestamp}) {
    return TranscriptMessage(
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TranscriptMessage &&
          runtimeType == other.runtimeType &&
          text == other.text &&
          timestamp == other.timestamp;

  @override
  int get hashCode => text.hashCode ^ timestamp.hashCode;
}

/// Utility functions for transcript formatting
class TranscriptUtils {
  TranscriptUtils._();

  /// Formats timestamp for display
  static String formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 10) {
      return 'Just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    }
  }

  /// Gets appropriate header icon based on status
  static IconData getHeaderIcon(HermesStatus status) {
    switch (status) {
      case HermesStatus.listening:
        return HermesIcons.listening;
      case HermesStatus.translating:
        return HermesIcons.translating;
      default:
        return HermesIcons.microphone;
    }
  }

  /// Gets header title based on status and history
  static String getHeaderTitle(HermesStatus status, bool hasEverSpoken) {
    switch (status) {
      case HermesStatus.listening:
        return 'Listening';
      case HermesStatus.translating:
        return 'Processing Speech';
      case HermesStatus.buffering:
        return hasEverSpoken ? 'Speech History' : 'Speech Transcript';
      default:
        return hasEverSpoken ? 'Speech History' : 'Ready to Listen';
    }
  }

  /// Gets header subtitle based on status and history
  static String getHeaderSubtitle(HermesStatus status, bool hasEverSpoken) {
    switch (status) {
      case HermesStatus.listening:
        return 'Your speech appears here in real-time';
      case HermesStatus.translating:
        return 'Converting speech to text...';
      case HermesStatus.buffering:
        return hasEverSpoken
            ? 'Your recent speech messages'
            : 'Start speaking to see your words here';
      default:
        return hasEverSpoken
            ? 'Your speech messages from this session'
            : 'Start speaking when you\'re ready';
    }
  }

  /// Gets empty state title
  static String getEmptyStateTitle(HermesStatus status, bool hasEverSpoken) {
    if (hasEverSpoken) {
      return 'No recent messages';
    }

    switch (status) {
      case HermesStatus.listening:
        return 'Start speaking';
      case HermesStatus.buffering:
        return 'Ready to listen';
      default:
        return 'Welcome to your session';
    }
  }

  /// Gets empty state subtitle
  static String getEmptyStateSubtitle(HermesStatus status, bool hasEverSpoken) {
    if (hasEverSpoken) {
      return 'Your speech messages will appear here when you start talking';
    }

    switch (status) {
      case HermesStatus.listening:
        return 'Your words will appear here as you speak';
      case HermesStatus.buffering:
        return 'Getting ready to capture your speech';
      default:
        return 'Your speech will be displayed here as you talk, creating a real-time transcript for this session';
    }
  }
}
