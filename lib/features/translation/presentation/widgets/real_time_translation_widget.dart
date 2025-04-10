// lib/features/translation/presentation/widgets/real_time_translation_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/translation/presentation/controllers/real_time_translation_controller.dart';
import 'package:hermes/features/translation/presentation/widgets/transcript_list.dart';
import 'package:hermes/features/translation/presentation/widgets/translation_error_message.dart';
import 'package:hermes/features/translation/presentation/widgets/translation_status_header.dart';

/// Widget that provides real-time transcription and translation
class RealTimeTranslationWidget extends StatefulWidget {
  /// The session ID
  final String sessionId;

  /// Source language of the speaker
  final LanguageSelection sourceLanguage;

  /// Target language for translation
  final LanguageSelection targetLanguage;

  /// Whether to show the source language text
  final bool showSourceText;

  /// Whether this widget is for the speaker view
  final bool isSpeakerView;

  /// Creates a new [RealTimeTranslationWidget]
  const RealTimeTranslationWidget({
    super.key,
    required this.sessionId,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.showSourceText = false,
    this.isSpeakerView = false,
  });

  @override
  State<RealTimeTranslationWidget> createState() =>
      _RealTimeTranslationWidgetState();
}

class _RealTimeTranslationWidgetState extends State<RealTimeTranslationWidget> {
  late RealTimeTranslationController _controller;

  @override
  void initState() {
    super.initState();

    // Initialize controller
    _controller = RealTimeTranslationController();
    _controller.initialize(
      sessionId: widget.sessionId,
      sourceLanguage: widget.sourceLanguage,
      targetLanguage: widget.targetLanguage,
      autoStart: widget.isSpeakerView,
    );
  }

  @override
  void didUpdateWidget(RealTimeTranslationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Handle language changes
    if (oldWidget.sourceLanguage.languageCode !=
        widget.sourceLanguage.languageCode) {
      _controller.initialize(
        sessionId: widget.sessionId,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
      );
    } else if (oldWidget.targetLanguage.languageCode !=
        widget.targetLanguage.languageCode) {
      _controller.changeTargetLanguage(widget.targetLanguage);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use ChangeNotifierProvider to rebuild only when controller state changes
    return ChangeNotifierProvider.value(
      value: _controller,
      child: SafeArea(child: _buildContent()),
    );
  }

  Widget _buildContent() {
    return Column(
      children: [
        // Header with status and controls
        Consumer<RealTimeTranslationController>(
          builder:
              (context, controller, child) => TranslationStatusHeader(
                isListening: controller.isListening,
                sourceLanguage: widget.sourceLanguage,
                targetLanguage: widget.targetLanguage,
                isSpeakerView: widget.isSpeakerView,
                onToggleListening:
                    widget.isSpeakerView ? controller.toggleListening : null,
              ),
        ),

        // Error message (if any)
        Consumer<RealTimeTranslationController>(
          builder: (context, controller, child) {
            if (controller.errorMessage == null) {
              return const SizedBox.shrink();
            }
            return TranslationErrorMessage(message: controller.errorMessage!);
          },
        ),

        // Transcript list (takes remaining space)
        Expanded(
          child: Consumer<RealTimeTranslationController>(
            builder: (context, controller, child) {
              return TranscriptList(
                transcripts: controller.transcripts,
                translations: controller.translations,
                partialTranscript: controller.currentPartialTranscript,
                isListening: controller.isListening,
                sourceLanguage: widget.sourceLanguage,
                targetLanguage: widget.targetLanguage,
                showSourceText: widget.showSourceText,
              );
            },
          ),
        ),
      ],
    );
  }
}
