// lib/features/session/presentation/widgets/session_status_bar.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/utils/extensions.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';

/// Status bar widget for the active session page
class SessionStatusBar extends StatelessWidget {
  /// Whether the speaker is currently listening
  final bool isListening;

  /// Whether listening is paused
  final bool isPaused;

  /// Language of the speaker
  final LanguageSelection language;

  /// Number of listeners in the session
  final int listenerCount;

  /// Creates a new [SessionStatusBar]
  const SessionStatusBar({
    super.key,
    required this.isListening,
    required this.isPaused,
    required this.language,
    required this.listenerCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: context.theme.primaryColor.withOpacity(0.1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Status indicator (speaking/paused/not speaking)
          Row(
            children: [
              Icon(_getStatusIcon(), color: _getStatusColor(), size: 20),
              const SizedBox(width: 8),
              Text(
                _getStatusText(),
                style: TextStyle(
                  color: _getStatusColor(),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          // Language indicator
          Row(
            children: [
              Text(language.flagEmoji),
              const SizedBox(width: 4),
              Text(language.englishName),
            ],
          ),

          // Listeners count
          Row(
            children: [
              const Icon(Icons.people, size: 20),
              const SizedBox(width: 4),
              Text('$listenerCount', style: context.textTheme.bodyMedium),
            ],
          ),
        ],
      ),
    );
  }

  /// Get the appropriate status icon
  IconData _getStatusIcon() {
    if (!isListening) return Icons.mic_off;
    return isPaused ? Icons.pause : Icons.mic;
  }

  /// Get the appropriate status color
  Color _getStatusColor() {
    if (!isListening) return Colors.grey;
    return isPaused ? Colors.amber : Colors.green;
  }

  /// Get the appropriate status text
  String _getStatusText() {
    if (!isListening) return 'Not Speaking';
    return isPaused ? 'Paused' : 'Speaking';
  }
}
