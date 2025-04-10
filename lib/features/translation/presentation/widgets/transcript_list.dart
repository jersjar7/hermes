// lib/features/translation/presentation/widgets/transcript_list.dart

import 'package:flutter/material.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/domain/entities/translation.dart';
import 'package:hermes/features/translation/presentation/widgets/partial_transcript_item.dart';
import 'package:hermes/features/translation/presentation/widgets/transcript_item.dart';

/// Widget to display the list of transcripts and translations
class TranscriptList extends StatefulWidget {
  /// List of transcripts to display
  final List<Transcript> transcripts;

  /// List of translations to display
  final List<Translation> translations;

  /// Current partial transcript text
  final String partialTranscript;

  /// Whether currently listening for transcription
  final bool isListening;

  /// Source language of the speaker
  final LanguageSelection sourceLanguage;

  /// Target language for translation
  final LanguageSelection targetLanguage;

  /// Whether to show the source language text
  final bool showSourceText;

  /// Creates a new [TranscriptList]
  const TranscriptList({
    super.key,
    required this.transcripts,
    required this.translations,
    required this.sourceLanguage,
    required this.targetLanguage,
    this.partialTranscript = '',
    this.isListening = false,
    this.showSourceText = false,
  });

  @override
  State<TranscriptList> createState() => _TranscriptListState();
}

class _TranscriptListState extends State<TranscriptList> {
  final ScrollController _scrollController = ScrollController();
  bool _autoscroll = true;

  @override
  void initState() {
    super.initState();
    // Set up scroll listener to detect manual scrolling
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TranscriptList oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Scroll to bottom when new content arrives if autoscroll is enabled
    if (_autoscroll &&
        (widget.transcripts.length > oldWidget.transcripts.length ||
            widget.translations.length > oldWidget.translations.length ||
            widget.partialTranscript != oldWidget.partialTranscript)) {
      _scrollToBottom();
    }
  }

  void _scrollListener() {
    // Detect if user has manually scrolled up
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      // Disable autoscroll if user scrolls up or more than 100 pixels from bottom
      _autoscroll = position.pixels >= position.maxScrollExtent - 100;
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      Future.delayed(const Duration(milliseconds: 100), () {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if there's any content to display
    if (widget.transcripts.isEmpty && widget.partialTranscript.isEmpty) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        // The transcript list
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          physics: const AlwaysScrollableScrollPhysics(),
          itemCount: widget.transcripts.length + (_showPartial() ? 1 : 0),
          itemBuilder: (context, index) {
            // Check if this is the partial transcript item
            if (_showPartial() && index == widget.transcripts.length) {
              return _buildPartialItem();
            }

            // Regular transcript item
            return _buildTranscriptItem(index);
          },
        ),

        // "Scroll to bottom" button that appears when not at the bottom
        if (!_autoscroll)
          Positioned(
            right: 16,
            bottom: 16,
            child: FloatingActionButton.small(
              onPressed: () {
                _autoscroll = true;
                _scrollToBottom();
              },
              backgroundColor: Colors.white,
              child: const Icon(Icons.arrow_downward),
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        'Waiting for speech...',
        style: TextStyle(color: Colors.grey),
      ),
    );
  }

  bool _showPartial() {
    return widget.partialTranscript.isNotEmpty && widget.isListening;
  }

  Widget _buildTranscriptItem(int index) {
    final transcript = widget.transcripts[index];

    // Find the corresponding translation (if any)
    final translation =
        widget.translations.isNotEmpty && index < widget.translations.length
            ? widget.translations[index]
            : null;

    return TranscriptItem(
      transcript: transcript,
      translation: translation,
      sourceLanguage: widget.sourceLanguage,
      targetLanguage: widget.targetLanguage,
      showSourceText: widget.showSourceText,
    );
  }

  Widget _buildPartialItem() {
    // Find the partial translation (if any)
    final partialTranslation = _findPartialTranslation();

    return PartialTranscriptItem(
      partialText: widget.partialTranscript,
      partialTranslation: partialTranslation,
      sourceLanguage: widget.sourceLanguage,
      targetLanguage: widget.targetLanguage,
      showSourceText: widget.showSourceText,
    );
  }

  Translation? _findPartialTranslation() {
    if (widget.translations.isEmpty) {
      return null;
    }

    final lastTranslation = widget.translations.last;

    // Check if this translation corresponds to a final transcript
    // If it does, then it's not a translation of the partial transcript
    final isForFinalTranscript = widget.transcripts.any(
      (t) => t.text == lastTranslation.sourceText,
    );

    return isForFinalTranscript ? null : lastTranslation;
  }
}
