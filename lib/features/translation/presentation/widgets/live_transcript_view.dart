// lib/features/translation/presentation/widgets/live_transcript_view.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';

/// Widget for displaying live transcription
/// This is a placeholder that will be fully implemented in Phase 2
class LiveTranscriptView extends StatefulWidget {
  /// ID of the session
  final String sessionId;

  /// Source language of the speaker
  final LanguageSelection sourceLanguage;

  /// Target language for translation
  final LanguageSelection targetLanguage;

  /// Creates a new [LiveTranscriptView]
  const LiveTranscriptView({
    super.key,
    required this.sessionId,
    required this.sourceLanguage,
    required this.targetLanguage,
  });

  @override
  State<LiveTranscriptView> createState() => _LiveTranscriptViewState();
}

class _LiveTranscriptViewState extends State<LiveTranscriptView> {
  final List<_TranscriptItem> _transcriptItems = [];
  Timer? _simulationTimer;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // For demo purposes only: simulate incoming transcripts
    _startSimulation();
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void _startSimulation() {
    // This is only for placeholder UI - will be replaced with real implementation
    final demoTexts = [
      "Welcome to this session!",
      "I'm excited to share these ideas with you today.",
      "The translation feature allows everyone to understand in their own language.",
      "This is just a simulation of how the live transcript will look.",
      "In Phase 2, we'll implement the real speech-to-text and translation features.",
      "You'll be able to see the translation in your selected language as I speak.",
      "This helps break down language barriers in real-time.",
      "Thank you for testing out the Hermes app!",
    ];

    int index = 0;
    _simulationTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (index < demoTexts.length) {
        setState(() {
          _transcriptItems.add(
            _TranscriptItem(text: demoTexts[index], timestamp: DateTime.now()),
          );

          // Scroll to bottom after adding new item
          _scrollToBottom();
        });
        index++;
      } else {
        timer.cancel();
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Header
        Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          color: Colors.grey.shade200,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Live Transcript',
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
        ),

        // Implementation note
        Container(
          padding: const EdgeInsets.all(8),
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.shade100,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.amber),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Real-time transcription and translation will be implemented in Phase 2',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),

        // Transcript list
        Expanded(
          child:
              _transcriptItems.isEmpty
                  ? const Center(
                    child: Text(
                      'Waiting for speaker...',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                  : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: _transcriptItems.length,
                    itemBuilder: (context, index) {
                      final item = _transcriptItems[index];
                      return _TranscriptItemWidget(item: item);
                    },
                  ),
        ),
      ],
    );
  }
}

/// Model class for a transcript item
class _TranscriptItem {
  /// The transcribed text
  final String text;

  /// When the transcript was received
  final DateTime timestamp;

  /// Creates a new [_TranscriptItem]
  _TranscriptItem({required this.text, required this.timestamp});
}

/// Widget for displaying a transcript item
class _TranscriptItemWidget extends StatelessWidget {
  /// The transcript item to display
  final _TranscriptItem item;

  /// Creates a new [_TranscriptItemWidget]
  const _TranscriptItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Timestamp
          Text(
            _formatTimestamp(item.timestamp),
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),

          const SizedBox(height: 4),

          // Transcript text bubble
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Text(item.text, style: const TextStyle(fontSize: 16)),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    return '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }
}
