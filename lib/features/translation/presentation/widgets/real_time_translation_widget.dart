// lib/features/translation/presentation/widgets/real_time_translation_widget.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/translation/presentation/controllers/real_time_translation_controller.dart';
import 'package:hermes/features/translation/presentation/widgets/transcript_list.dart';

/// Error notification for error handling
class ErrorNotification extends Notification {
  final String message;
  ErrorNotification(this.message);
}

/// Widget for displaying real-time translation
class RealTimeTranslationWidget extends StatefulWidget {
  /// ID of the session
  final String sessionId;

  /// Source language of the speaker
  final LanguageSelection sourceLanguage;

  /// Target language for translation
  final LanguageSelection targetLanguage;

  /// Whether to show the source language text
  final bool showSourceText;

  /// Whether this is for the speaker view
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
  RealTimeTranslationController? _controller;
  bool _isInitializing = false;
  String? _initError;

  @override
  void initState() {
    super.initState();
    _controller = RealTimeTranslationController();
    _initializeController();
  }

  Future<void> _initializeController() async {
    setState(() {
      _isInitializing = true;
      _initError = null;
    });

    try {
      await _controller?.initialize(
        sessionId: widget.sessionId,
        sourceLanguage: widget.sourceLanguage,
        targetLanguage: widget.targetLanguage,
        autoStart: widget.isSpeakerView,
      );
    } catch (error) {
      // Set local error state
      setState(() {
        _initError = error.toString();
      });

      // Propagate errors to parent via notification
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ErrorNotification(error.toString()).dispatch(context);
        }
      });
    } finally {
      if (mounted) {
        setState(() {
          _isInitializing = false;
        });
      }
    }
  }

  @override
  void didUpdateWidget(RealTimeTranslationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller == null) return;

    // Reinitialize if essential parameters change
    if (oldWidget.sessionId != widget.sessionId ||
        oldWidget.sourceLanguage.languageCode !=
            widget.sourceLanguage.languageCode) {
      _initializeController();
    } else if (oldWidget.targetLanguage.languageCode !=
        widget.targetLanguage.languageCode) {
      // Just update the target language if only that changed
      _controller?.changeTargetLanguage(widget.targetLanguage).catchError((
        error,
      ) {
        if (mounted) {
          ErrorNotification(error.toString()).dispatch(context);
        }
      });
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
    // Show loading state
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Initializing translation...'),
          ],
        ),
      );
    }

    // Show error state
    if (_initError != null && _controller == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, color: Colors.red.shade700, size: 48),
            const SizedBox(height: 16),
            Text(
              'Failed to initialize translation',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.red.shade700,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(
                _initError!,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              onPressed: _initializeController,
            ),
          ],
        ),
      );
    }

    if (_controller == null) {
      return const Center(child: Text('Controller not initialized'));
    }

    return ChangeNotifierProvider.value(
      value: _controller!,
      child: Container(
        color: Colors.grey.shade50,
        child: Consumer<RealTimeTranslationController>(
          builder: (context, controller, child) {
            // Check for errors and propagate them
            if (controller.errorMessage != null) {
              // Schedule notification on the next frame to avoid build-phase errors
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ErrorNotification(controller.errorMessage!).dispatch(context);
              });
            }

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
    );
  }
}
