// lib/features/session/presentation/widgets/organisms/transcript_chat_box.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/durations.dart';
import '../molecules/transcript_header.dart';
import '../molecules/transcript_messages_list.dart';
import '../molecules/transcript_empty_state.dart';
import '../molecules/current_speech_indicator.dart';
import '../atoms/scroll_to_bottom_button.dart';
import '../../utils/transcript_message.dart';

/// FIXED: Simple transcript chat box with clear separation of partials vs permanent messages
class TranscriptChatBox extends ConsumerStatefulWidget {
  const TranscriptChatBox({super.key});

  @override
  ConsumerState<TranscriptChatBox> createState() => _TranscriptChatBoxState();
}

class _TranscriptChatBoxState extends ConsumerState<TranscriptChatBox> {
  final ScrollController _scrollController = ScrollController();
  final List<TranscriptMessage> _messages = [];

  // 🎯 CLEAR SEPARATION: Track different types of transcripts
  String? _lastProcessedSentence; // For permanent messages
  String? _currentPartialTranscript; // For real-time partials

  bool _showScrollToBottomButton = false;
  bool _hasEverSpoken = false;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(hermesControllerProvider);
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(HermesSpacing.md),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: sessionState.when(
        data: (state) {
          // 🎯 SIMPLE UPDATE: Handle updates after build using addPostFrameCallback
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _handleStateUpdate(state);
          });

          return Column(
            children: [
              // Header with dynamic status
              TranscriptHeader(
                status: state.status,
                hasEverSpoken: _hasEverSpoken,
                messageCount: _messages.length,
              ),

              // Messages area
              Expanded(
                child: Stack(
                  children: [
                    _buildMessagesArea(context, state),
                    ScrollToBottomButton(
                      onPressed: _scrollToBottom,
                      isVisible: _showScrollToBottomButton,
                    ),
                  ],
                ),
              ),

              // Current speaking indicator
              CurrentSpeechIndicator(
                status: state.status,
                currentText: _currentPartialTranscript,
              ),
            ],
          );
        },
        loading: () => _buildLoadingState(context, theme),
        error: (error, _) => _buildErrorState(context, theme, error),
      ),
    );
  }

  Widget _buildMessagesArea(BuildContext context, state) {
    if (_messages.isEmpty) {
      return TranscriptEmptyState(
        status: state.status,
        hasEverSpoken: _hasEverSpoken,
      );
    }

    return TranscriptMessagesList(
      messages: _messages,
      scrollController: _scrollController,
      onScrollStateChanged: (userHasScrolledUp) {
        setState(() {
          _showScrollToBottomButton = userHasScrolledUp && _messages.isNotEmpty;
        });
      },
    );
  }

  Widget _buildLoadingState(BuildContext context, ThemeData theme) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          SizedBox(height: HermesSpacing.md),
          Text('Initializing transcript...'),
        ],
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, ThemeData theme, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HermesSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: HermesSpacing.md),
            Text(
              'Transcript Unavailable',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: HermesSpacing.xs),
            const Text(
              'Unable to display speech transcript',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// 🎯 SIMPLIFIED: Clean state update with clear separation
  void _handleStateUpdate(state) {
    final currentTranscript = state.lastTranscript;
    final processedSentence = state.lastProcessedSentence;
    final isListening = state.status == HermesStatus.listening;

    // Track if user has ever spoken
    if (currentTranscript != null && currentTranscript.isNotEmpty) {
      _hasEverSpoken = true;
    }

    // 1️⃣ HANDLE PERMANENT MESSAGES: Add when buffer processing completes
    if (processedSentence != null &&
        processedSentence.isNotEmpty &&
        processedSentence != _lastProcessedSentence) {
      print(
        '✅ [TranscriptChatBox] Adding permanent message: "$processedSentence"',
      );

      if (mounted) {
        setState(() {
          _messages.add(
            TranscriptMessage(
              text: processedSentence,
              timestamp: DateTime.now(),
            ),
          );

          _lastProcessedSentence = processedSentence;

          // Keep only last 50 messages
          if (_messages.length > 50) {
            _messages.removeAt(0);
          }
        });

        // Always auto-scroll for permanent messages
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    }

    // 2️⃣ HANDLE PARTIAL MESSAGES: Show real-time speech feedback
    if (isListening &&
        currentTranscript != null &&
        currentTranscript.isNotEmpty &&
        currentTranscript != _currentPartialTranscript) {
      if (mounted) {
        setState(() {
          _currentPartialTranscript = currentTranscript;
        });
      }
    }
    // Clear partials when not listening
    else if (!isListening && _currentPartialTranscript != null) {
      if (mounted) {
        setState(() {
          _currentPartialTranscript = null;
        });
      }
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: HermesDurations.fast,
        curve: Curves.easeOut,
      );
    }
  }
}
