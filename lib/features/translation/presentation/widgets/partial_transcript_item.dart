// lib/features/translation/presentation/widgets/partial_transcript_item.dart

import 'package:flutter/material.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/translation/domain/entities/translation.dart';

/// Widget for displaying a partial (in-progress) transcript
class PartialTranscriptItem extends StatelessWidget {
  /// Current partial transcript text
  final String partialText;

  /// Partial translation (if available)
  final Translation? partialTranslation;

  /// Source language
  final LanguageSelection sourceLanguage;

  /// Target language for translation
  final LanguageSelection targetLanguage;

  /// Whether to show the source language text
  final bool showSourceText;

  /// Creates a new [PartialTranscriptItem]
  const PartialTranscriptItem({
    super.key,
    required this.partialText,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.partialTranslation,
    this.showSourceText = false,
  });

  @override
  Widget build(BuildContext context) {
    // Skip if empty text
    if (partialText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source text (if enabled)
          if (showSourceText ||
              sourceLanguage.languageCode == targetLanguage.languageCode)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.shade400,
                  style: BorderStyle.solid,
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sourceLanguage.flagEmoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      partialText,
                      style: const TextStyle(
                        fontSize: 16,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // Translation (if available)
          if (_shouldShowPartialTranslation())
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.blue.shade200,
                    style: BorderStyle.solid,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      targetLanguage.flagEmoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        partialTranslation!.targetText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontStyle: FontStyle.italic,
                          color: Colors.blue,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Determine if we should show the partial translation
  bool _shouldShowPartialTranslation() {
    return partialTranslation != null &&
        partialTranslation!.sourceText.isNotEmpty &&
        partialTranslation!.targetText.isNotEmpty &&
        sourceLanguage.languageCode != targetLanguage.languageCode;
  }
}
