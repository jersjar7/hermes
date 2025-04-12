// lib/features/translation/presentation/widgets/transcript_list.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/domain/entities/translation.dart';
import 'package:hermes/features/translation/presentation/widgets/transcript_item.dart';
import 'package:hermes/features/translation/presentation/widgets/partial_transcript_item.dart';

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
  List<Transcript> _visibleTranscripts = [];
  List<Translation> _visibleTranslations = [];
  String _visiblePartialTranscript = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);
    _updateVisibleContent();
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
    _updateVisibleContent();

    // Scroll to bottom if autoscroll is enabled
    if (_autoscroll) {
      _scrollToBottom();
    }
  }

  void _updateVisibleContent() {
    setState(() {
      _visibleTranscripts = List.from(widget.transcripts);
      _visibleTranslations = List.from(widget.translations);
      _visiblePartialTranscript = widget.partialTranscript;
    });
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      _autoscroll = position.pixels >= position.maxScrollExtent - 100;
    }
  }

  void _scrollToBottom() {
    // Only try to scroll if controller is attached and has clients
    if (_scrollController.hasClients) {
      try {
        // Safely check if positions exist before accessing position
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            // Check again after delay
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      } catch (e) {
        // Log the error but don't crash the app
        debugPrint("Scroll error: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Check if there's any content to display
    if (_visibleTranscripts.isEmpty && _visiblePartialTranscript.isEmpty) {
      return _buildEmptyState();
    }

    return Stack(
      children: [
        ListView.builder(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          physics: const AlwaysScrollableScrollPhysics(),
          // Use the cached visible lists instead of widget properties directly
          itemCount: _visibleTranscripts.length + (_showPartial() ? 1 : 0),
          itemBuilder: (context, index) {
            // Check if this is the partial transcript item
            if (_showPartial() && index == _visibleTranscripts.length) {
              return _buildPartialItem();
            }

            // Regular transcript item
            return _buildTranscriptItem(index);
          },
        ),

        // "Scroll to bottom" button with fade animation
        AnimatedOpacity(
          opacity: _autoscroll ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 200),
          child: Align(
            alignment: Alignment.bottomRight,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FloatingActionButton.small(
                onPressed: () {
                  _autoscroll = true;
                  _scrollToBottom();
                },
                backgroundColor: Colors.white,
                child: const Icon(Icons.arrow_downward),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_none, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'Waiting for speech...',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  bool _showPartial() {
    return _visiblePartialTranscript.isNotEmpty && widget.isListening;
  }

  Widget _buildTranscriptItem(int index) {
    final transcript = _visibleTranscripts[index];

    // Find the corresponding translation (if any)
    final translation =
        _visibleTranslations.isNotEmpty && index < _visibleTranslations.length
            ? _visibleTranslations[index]
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
      partialText: _visiblePartialTranscript,
      partialTranslation: partialTranslation,
      sourceLanguage: widget.sourceLanguage,
      targetLanguage: widget.targetLanguage,
      showSourceText: widget.showSourceText,
    );
  }

  Translation? _findPartialTranslation() {
    if (_visibleTranslations.isEmpty) {
      return null;
    }

    final lastTranslation = _visibleTranslations.last;

    // Check if this translation corresponds to a final transcript
    // If it does, then it's not a translation of the partial transcript
    final isForFinalTranscript = _visibleTranscripts.any(
      (t) => t.text == lastTranslation.sourceText,
    );

    return isForFinalTranscript ? null : lastTranslation;
  }
}
