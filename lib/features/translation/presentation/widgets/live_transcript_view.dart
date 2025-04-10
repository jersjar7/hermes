// lib/features/translation/presentation/widgets/live_transcript_view.dart

import 'package:flutter/material.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/translation/presentation/widgets/real_time_translation_widget.dart';

/// Widget for displaying live transcription
class LiveTranscriptView extends StatefulWidget {
  /// ID of the session
  final String sessionId;

  /// Source language of the speaker
  final LanguageSelection sourceLanguage;

  /// Target language for translation
  final LanguageSelection targetLanguage;

  /// Whether this is for the speaker view
  final bool isSpeakerView;

  /// Whether to show the header
  final bool showHeader;

  /// Creates a new [LiveTranscriptView]
  const LiveTranscriptView({
    super.key,
    required this.sessionId,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.isSpeakerView = false,
    this.showHeader = true,
  });

  @override
  State<LiveTranscriptView> createState() => _LiveTranscriptViewState();
}

class _LiveTranscriptViewState extends State<LiveTranscriptView> {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header (optional)
            if (widget.showHeader) _buildHeader(),

            // Real-time translation widget (main content)
            Expanded(
              child: RealTimeTranslationWidget(
                sessionId: widget.sessionId,
                sourceLanguage: widget.sourceLanguage,
                targetLanguage: widget.targetLanguage,
                showSourceText:
                    widget.isSpeakerView ||
                    widget.sourceLanguage.languageCode ==
                        widget.targetLanguage.languageCode,
                isSpeakerView: widget.isSpeakerView,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final headerText =
        widget.isSpeakerView ? 'Your Speech' : 'Live Translation';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Colors.grey.shade200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            headerText,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          Row(
            children: [
              Text(
                '${widget.sourceLanguage.flagEmoji} → ${widget.targetLanguage.flagEmoji}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: Colors.green,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
