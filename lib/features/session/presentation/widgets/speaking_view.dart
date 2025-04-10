// lib/features/session/presentation/widgets/speaking_view.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/utils/extensions.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/translation/presentation/widgets/live_transcript_view.dart';

/// View shown while the speaker is speaking
class SpeakingView extends StatelessWidget {
  /// Session ID
  final String sessionId;

  /// Session name
  final String sessionName;

  /// Session code
  final String sessionCode;

  /// Source language of the speaker
  final LanguageSelection language;

  /// Whether to show the transcription area
  final bool showTranscription;

  /// Number of listeners in the session
  final int listenerCount;

  /// Callback for toggling transcription visibility
  final VoidCallback onToggleTranscriptionVisibility;

  /// Creates a new [SpeakingView]
  const SpeakingView({
    super.key,
    required this.sessionId,
    required this.sessionName,
    required this.sessionCode,
    required this.language,
    required this.showTranscription,
    required this.listenerCount,
    required this.onToggleTranscriptionVisibility,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Upper part with minimal info and controls
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Session info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Session: $sessionName',
                      style: context.textTheme.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Code: $sessionCode',
                      style: context.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),

              // Transcription visibility toggle
              IconButton(
                icon: Icon(
                  showTranscription ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: onToggleTranscriptionVisibility,
                tooltip:
                    showTranscription
                        ? 'Hide transcription'
                        : 'Show transcription',
              ),
            ],
          ),
        ),

        // Transcription view (if visible)
        if (showTranscription)
          Expanded(
            child: LiveTranscriptView(
              sessionId: sessionId,
              sourceLanguage: language,
              targetLanguage: language,
              isSpeakerView: true,
            ),
          )
        else
          Expanded(child: _buildMinimalView(context)),
      ],
    );
  }

  /// Build a minimal view when transcription is hidden
  Widget _buildMinimalView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mic, size: 64, color: Colors.green),
          const SizedBox(height: 16),
          Text('Actively Speaking', style: context.textTheme.headlineSmall),
          Text(
            '$listenerCount ${listenerCount == 1 ? 'listener' : 'listeners'} connected',
            style: context.textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}
