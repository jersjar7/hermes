// lib/features/translation/presentation/widgets/translation_status_header.dart

import 'package:flutter/material.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';

/// Header widget that shows the translation status and controls
class TranslationStatusHeader extends StatelessWidget {
  /// Whether currently listening for transcription
  final bool isListening;

  /// Source language of the speaker
  final LanguageSelection sourceLanguage;

  /// Target language for translation
  final LanguageSelection targetLanguage;

  /// Whether this is for speaker view
  final bool isSpeakerView;

  /// Callback for when the listening toggle button is pressed
  final VoidCallback? onToggleListening;

  /// Creates a new [TranslationStatusHeader]
  const TranslationStatusHeader({
    super.key,
    required this.isListening,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.isSpeakerView = false,
    this.onToggleListening,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 1),
            blurRadius: 2,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Status indicator
          _buildStatusIndicator(),

          // Language indicator
          _buildLanguageIndicator(),

          // Control button (for speaker only)
          if (isSpeakerView && onToggleListening != null) _buildControlButton(),
        ],
      ),
    );
  }

  /// Build the status indicator with icon and text
  Widget _buildStatusIndicator() {
    return Row(
      children: [
        Icon(
          isListening ? Icons.record_voice_over : Icons.voice_over_off,
          color: isListening ? Colors.green : Colors.grey,
          size: 18,
        ),
        const SizedBox(width: 6),
        Text(
          isListening
              ? isSpeakerView
                  ? 'Speaking'
                  : 'Listening'
              : isSpeakerView
              ? 'Not Speaking'
              : 'Waiting',
          style: TextStyle(
            color: isListening ? Colors.green : Colors.grey,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  /// Build the language indicator showing source and target languages
  Widget _buildLanguageIndicator() {
    // If source and target are the same (e.g. for speaker view), just show one flag
    if (sourceLanguage.languageCode == targetLanguage.languageCode) {
      return Row(
        children: [
          Text(sourceLanguage.flagEmoji, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 4),
          Text(
            sourceLanguage.englishName,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      );
    }

    // Otherwise show source → target
    return Row(
      children: [
        Text(sourceLanguage.flagEmoji, style: const TextStyle(fontSize: 14)),
        const Icon(Icons.arrow_forward, size: 10),
        Text(targetLanguage.flagEmoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 4),
        Text(targetLanguage.englishName, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  /// Build the control button for starting/stopping listening
  Widget _buildControlButton() {
    return SizedBox(
      height: 30,
      width: 30,
      child: IconButton(
        padding: EdgeInsets.zero,
        icon: Icon(
          isListening ? Icons.stop_circle : Icons.play_circle,
          size: 24,
        ),
        onPressed: onToggleListening,
        tooltip: isListening ? 'Stop listening' : 'Start listening',
      ),
    );
  }
}
