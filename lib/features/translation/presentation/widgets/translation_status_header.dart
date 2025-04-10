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
          isListening ? Icons.mic : Icons.mic_off,
          color: isListening ? Colors.green : Colors.grey,
        ),
        const SizedBox(width: 8),
        Text(
          isListening ? 'Listening...' : 'Not listening',
          style: TextStyle(
            color: isListening ? Colors.green : Colors.grey,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  /// Build the language indicator showing source and target languages
  Widget _buildLanguageIndicator() {
    return Row(
      children: [
        Text(sourceLanguage.flagEmoji, style: const TextStyle(fontSize: 16)),
        const Icon(Icons.arrow_forward, size: 12),
        Text(targetLanguage.flagEmoji, style: const TextStyle(fontSize: 16)),
      ],
    );
  }

  /// Build the control button for starting/stopping listening
  Widget _buildControlButton() {
    return IconButton(
      icon: Icon(isListening ? Icons.stop : Icons.play_arrow),
      onPressed: onToggleListening,
      tooltip: isListening ? 'Stop listening' : 'Start listening',
    );
  }
}
