// lib/features/translation/presentation/widgets/real_time_translation_widget.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/translation/domain/entities/transcript.dart';
import 'package:hermes/features/translation/domain/entities/translation.dart';
import 'package:hermes/features/translation/domain/usecases/stream_transcription.dart';
import 'package:hermes/features/translation/domain/usecases/translate_text_chunk.dart';

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
  final StreamTranscription _streamTranscription =
      GetIt.instance<StreamTranscription>();
  final TranslateTextChunk _translateTextChunk =
      GetIt.instance<TranslateTextChunk>();

  StreamSubscription? _transcriptionSubscription;
  final List<Transcript> _transcripts = [];
  final List<Translation> _translations = [];

  bool _isListening = false;
  String? _errorMessage;
  String _lastTranslatedText = '';
  final ScrollController _scrollController = ScrollController();

  // For handling partial transcripts
  String _currentPartialTranscript = '';
  Timer? _translationDebounceTimer;

  @override
  void initState() {
    super.initState();
    if (widget.isSpeakerView) {
      // Auto-start listening for speaker view
      _startListening();
    }
  }

  @override
  void dispose() {
    _stopListening();
    _scrollController.dispose();
    _translationDebounceTimer?.cancel();
    super.dispose();
  }

  @override
  void didUpdateWidget(RealTimeTranslationWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    // If the target language changed, clear translations
    if (oldWidget.targetLanguage.languageCode !=
        widget.targetLanguage.languageCode) {
      setState(() {
        _translations.clear();
        _lastTranslatedText = '';
      });
    }

    // If the source language changed, restart transcription
    if (oldWidget.sourceLanguage.languageCode !=
            widget.sourceLanguage.languageCode &&
        _isListening) {
      _stopListening();
      _startListening();
    }
  }

  void _startListening() async {
    setState(() {
      _isListening = true;
      _errorMessage = null;
    });

    final params = StreamTranscriptionParams(
      sessionId: widget.sessionId,
      languageCode: widget.sourceLanguage.languageCode,
    );

    // Start streaming transcription
    final transcriptionStream = _streamTranscription(params);

    _transcriptionSubscription = transcriptionStream.listen(
      (result) {
        result.fold(
          (failure) {
            setState(() {
              _errorMessage = failure.message;
              _isListening = false;
            });
          },
          (transcript) {
            setState(() {
              // For final transcripts, add to list and translate
              if (transcript.isFinal) {
                // Only add if text is not empty
                if (transcript.text.trim().isNotEmpty) {
                  _transcripts.add(transcript);
                  _translateTranscript(transcript);
                  _currentPartialTranscript = '';

                  // Scroll to the bottom
                  _scrollToBottom();
                }
              } else {
                // Update partial transcript
                _currentPartialTranscript = transcript.text;

                // Debounce translation of partial transcripts
                _debouncedTranslate(transcript);
              }
            });
          },
        );
      },
      onError: (error) {
        setState(() {
          _errorMessage = error.toString();
          _isListening = false;
        });
      },
      onDone: () {
        setState(() {
          _isListening = false;
        });
      },
    );
  }

  void _debouncedTranslate(Transcript transcript) {
    _translationDebounceTimer?.cancel();

    // Only translate partial transcripts if they're stable enough
    if (transcript.text.length > 10) {
      _translationDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        _translateTranscript(transcript, isPartial: true);
      });
    }
  }

  void _translateTranscript(
    Transcript transcript, {
    bool isPartial = false,
  }) async {
    // Skip translation if target language is the same as source language
    if (widget.targetLanguage.languageCode ==
        widget.sourceLanguage.languageCode) {
      return;
    }

    // Skip if text is empty or the same as the last translated text
    if (transcript.text.trim().isEmpty ||
        transcript.text == _lastTranslatedText) {
      return;
    }

    final params = TranslateTextChunkParams(
      sessionId: widget.sessionId,
      sourceText: transcript.text,
      sourceLanguage: widget.sourceLanguage.languageCode,
      targetLanguage: widget.targetLanguage.languageCode,
    );

    final result = await _translateTextChunk(params);

    result.fold(
      (failure) {
        setState(() {
          // Only show error for final translations
          if (!isPartial) {
            _errorMessage = failure.message;
          }
        });
      },
      (translation) {
        setState(() {
          // For partial translations, replace the last one if it exists
          if (isPartial && _translations.isNotEmpty) {
            _translations.removeLast();
          }

          _translations.add(translation);
          _lastTranslatedText = transcript.text;

          // Scroll to bottom
          _scrollToBottom();
        });
      },
    );
  }

  void _stopListening() async {
    if (!_isListening) return;

    await _transcriptionSubscription?.cancel();
    _transcriptionSubscription = null;

    await _streamTranscription.stop();

    setState(() {
      _isListening = false;
    });
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
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
    return Column(
      children: [
        // Header with status and controls
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.grey.shade200,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Status indicator
              Row(
                children: [
                  Icon(
                    _isListening ? Icons.mic : Icons.mic_off,
                    color: _isListening ? Colors.green : Colors.grey,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _isListening ? 'Listening...' : 'Not listening',
                    style: TextStyle(
                      color: _isListening ? Colors.green : Colors.grey,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),

              // Language indicator
              Text(
                '${widget.sourceLanguage.flagEmoji} → ${widget.targetLanguage.flagEmoji}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),

              // Toggle button (for speaker view only)
              if (widget.isSpeakerView)
                IconButton(
                  icon: Icon(_isListening ? Icons.stop : Icons.play_arrow),
                  onPressed: _toggleListening,
                  tooltip: _isListening ? 'Stop listening' : 'Start listening',
                ),
            ],
          ),
        ),

        // Error message (if any)
        if (_errorMessage != null)
          Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red.shade100,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
              ],
            ),
          ),

        // Transcripts and translations list
        Expanded(child: _buildTranscriptionList()),
      ],
    );
  }

  Widget _buildTranscriptionList() {
    // Check if there's any content to display
    if (_transcripts.isEmpty && _currentPartialTranscript.isEmpty) {
      return const Center(
        child: Text(
          'Waiting for speech...',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Combine final transcripts with the current partial transcript
    final allTranscripts = [..._transcripts];

    // Only add current partial transcript if it's not empty
    final showPartial = _currentPartialTranscript.isNotEmpty && _isListening;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: allTranscripts.length + (showPartial ? 1 : 0),
      itemBuilder: (context, index) {
        // Check if this is the partial transcript item
        if (showPartial && index == allTranscripts.length) {
          return _buildPartialTranscriptItem();
        }

        // Regular transcript item
        final transcript = allTranscripts[index];

        // Find the corresponding translation (if any)
        final translation =
            _translations.isNotEmpty && index < _translations.length
                ? _translations[index]
                : null;

        return _buildTranscriptItem(transcript, translation);
      },
    );
  }

  Widget _buildPartialTranscriptItem() {
    // Find the partial translation (if any)
    final partialTranslation =
        _translations.isNotEmpty ? _translations.last : null;

    // Only show partial translation if it's for the current partial transcript
    final showPartialTranslation =
        partialTranslation != null &&
        !_transcripts
            .map((t) => t.text)
            .contains(partialTranslation.sourceText);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Source text (if enabled)
          if (widget.showSourceText ||
              widget.sourceLanguage.languageCode ==
                  widget.targetLanguage.languageCode)
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
                    widget.sourceLanguage.flagEmoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _currentPartialTranscript,
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
          if (showPartialTranslation)
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
                      widget.targetLanguage.flagEmoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        partialTranslation.targetText,
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

  Widget _buildTranscriptItem(Transcript transcript, Translation? translation) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            _formatTimestamp(transcript.timestamp),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 4),

          // Source text (if enabled)
          if (widget.showSourceText ||
              widget.sourceLanguage.languageCode ==
                  widget.targetLanguage.languageCode)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.sourceLanguage.flagEmoji,
                    style: const TextStyle(fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      transcript.text,
                      style: const TextStyle(fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),

          // Translation (if available)
          if (translation != null)
            Padding(
              padding: EdgeInsets.only(top: widget.showSourceText ? 8.0 : 0.0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.targetLanguage.flagEmoji,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        translation.targetText,
                        style: const TextStyle(fontSize: 16),
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

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }
}
