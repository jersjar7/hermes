// lib/features/translation/presentation/widgets/real_time_translation_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/translation/presentation/controllers/real_time_translation_controller.dart';
import 'package:hermes/features/translation/presentation/widgets/transcript_list.dart';
import 'package:hermes/features/translation/presentation/widgets/translation_error_message.dart';
import 'package:hermes/features/translation/presentation/widgets/translation_status_header.dart';

class RealTimeTranslationWidget extends StatefulWidget {
  final String sessionId;
  final LanguageSelection sourceLanguage;
  final LanguageSelection targetLanguage;
  final bool showSourceText;
  final bool isSpeakerView;

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
  RealTimeTranslationController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = RealTimeTranslationController();
    _controller?.initialize(
      sessionId: widget.sessionId,
      sourceLanguage: widget.sourceLanguage,
      targetLanguage: widget.targetLanguage,
      autoStart: widget.isSpeakerView,
    );
  }

  @override
  void didUpdateWidget(RealTimeTranslationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null) return;

    if (oldWidget.sourceLanguage.languageCode !=
        widget.sourceLanguage.languageCode) {
      _controller?.initialize(
        sessionId: widget.sessionId,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
      );
    } else if (oldWidget.targetLanguage.languageCode !=
        widget.targetLanguage.languageCode) {
      _controller?.changeTargetLanguage(widget.targetLanguage);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    _controller = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_controller == null) return const SizedBox.shrink();

    return ChangeNotifierProvider.value(
      value: _controller!,
      child: Container(
        color: Colors.grey.shade50,
        child: Column(
          children: [
            Consumer<RealTimeTranslationController>(
              builder:
                  (context, controller, child) => TranslationStatusHeader(
                    isListening: controller.isListening,
                    sourceLanguage: widget.sourceLanguage,
                    targetLanguage: widget.targetLanguage,
                    isSpeakerView: widget.isSpeakerView,
                    onToggleListening:
                        widget.isSpeakerView
                            ? controller.toggleListening
                            : null,
                  ),
            ),
            Consumer<RealTimeTranslationController>(
              builder: (context, controller, child) {
                if (controller.errorMessage == null)
                  return const SizedBox.shrink();
                return TranslationErrorMessage(
                  message: controller.errorMessage!,
                );
              },
            ),
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
        ),
      ),
    );
  }
}
