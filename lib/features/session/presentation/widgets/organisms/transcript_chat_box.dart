// lib/features/session/presentation/widgets/organisms/transcript_chat_box.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/core/presentation/constants/durations.dart';
import 'package:hermes/core/presentation/widgets/animations/fade_in_widget.dart';

/// Chat-like transcript box that displays speaker's speech in real-time.
/// Behaves like a messaging app with auto-scroll and manual scroll capability.
class TranscriptChatBox extends ConsumerStatefulWidget {
  const TranscriptChatBox({super.key});

  @override
  ConsumerState<TranscriptChatBox> createState() => _TranscriptChatBoxState();
}

class _TranscriptChatBoxState extends ConsumerState<TranscriptChatBox> {
  final ScrollController _scrollController = ScrollController();
  final List<TranscriptMessage> _messages = [];
  String? _lastProcessedTranscript;
  bool _userHasScrolledUp = false;
  bool _showScrollToBottomButton = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;

    final isAtBottom =
        _scrollController.offset >=
        _scrollController.position.maxScrollExtent - 50;

    setState(() {
      _userHasScrolledUp = !isAtBottom;
      _showScrollToBottomButton = !isAtBottom && _messages.isNotEmpty;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(hermesControllerProvider);
    final theme = Theme.of(context);

    return sessionState.when(
      data: (state) {
        _updateMessages(state);

        return Container(
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(HermesSpacing.md),
            border: Border.all(
              color: theme.colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Header
              _buildHeader(context, theme),

              // Messages area
              Expanded(
                child: Stack(
                  children: [
                    // Chat messages
                    _buildMessagesArea(context, theme, state),

                    // Scroll to bottom button
                    if (_showScrollToBottomButton)
                      _buildScrollToBottomButton(context, theme),
                  ],
                ),
              ),

              // Current speaking indicator (only when actively listening)
              if (state.status == HermesStatus.listening &&
                  state.lastTranscript != null &&
                  state.lastTranscript!.isNotEmpty)
                _buildCurrentSpeechIndicator(
                  context,
                  theme,
                  state.lastTranscript!,
                ),
            ],
          ),
        );
      },
      loading: () => _buildLoadingState(context),
      error: (error, _) => _buildErrorState(context, error),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            HermesIcons.microphone,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: HermesSpacing.sm),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Speech Transcript',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                'Your speech appears here in real-time',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_messages.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: HermesSpacing.sm,
                vertical: HermesSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.3,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_messages.length}',
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessagesArea(BuildContext context, ThemeData theme, state) {
    if (_messages.isEmpty) {
      return _buildEmptyState(context, theme);
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(HermesSpacing.sm),
      itemCount: _messages.length,
      itemBuilder: (context, index) {
        final message = _messages[index];
        final isLatest = index == _messages.length - 1;

        return FadeInWidget(
          duration: HermesDurations.fast,
          slideFrom: const Offset(0, 0.2),
          child: _buildMessageBubble(context, theme, message, isLatest),
        );
      },
    );
  }

  Widget _buildMessageBubble(
    BuildContext context,
    ThemeData theme,
    TranscriptMessage message,
    bool isLatest,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: HermesSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar/Icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              HermesIcons.microphone,
              size: 16,
              color: theme.colorScheme.primary,
            ),
          ),

          const SizedBox(width: HermesSpacing.sm),

          // Message content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Message bubble
                Container(
                  padding: const EdgeInsets.all(HermesSpacing.md),
                  decoration: BoxDecoration(
                    color:
                        isLatest
                            ? theme.colorScheme.primaryContainer.withValues(
                              alpha: 0.3,
                            )
                            : theme.colorScheme.surfaceContainerHighest,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(HermesSpacing.md),
                      bottomLeft: Radius.circular(HermesSpacing.md),
                      bottomRight: Radius.circular(HermesSpacing.md),
                    ),
                    border:
                        isLatest
                            ? Border.all(
                              color: theme.colorScheme.primary.withValues(
                                alpha: 0.3,
                              ),
                              width: 1,
                            )
                            : null,
                  ),
                  child: Text(
                    message.text,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          isLatest
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurface,
                      fontWeight:
                          isLatest ? FontWeight.w500 : FontWeight.normal,
                    ),
                  ),
                ),

                const SizedBox(height: HermesSpacing.xs),

                // Timestamp
                Text(
                  _formatTimestamp(message.timestamp),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentSpeechIndicator(
    BuildContext context,
    ThemeData theme,
    String currentText,
  ) {
    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Live indicator with pulsing animation
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: HermesSpacing.sm),

          // "Currently saying" label
          Text(
            'Speaking: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Current text (limited height)
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 60),
              child: SingleChildScrollView(
                child: Text(
                  currentText,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScrollToBottomButton(BuildContext context, ThemeData theme) {
    return Positioned(
      bottom: HermesSpacing.md,
      right: HermesSpacing.md,
      child: FloatingActionButton.small(
        onPressed: _scrollToBottom,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        child: const Icon(Icons.keyboard_arrow_down_rounded),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HermesSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              HermesIcons.microphone,
              size: 48,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: HermesSpacing.md),
            Text(
              'Start speaking',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: HermesSpacing.xs),
            Text(
              'Your speech will appear here as chat messages',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(HermesSpacing.md),
      ),
      child: const Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(HermesSpacing.md),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
            const SizedBox(height: HermesSpacing.md),
            Text(
              'Transcript Error',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: HermesSpacing.xs),
            Text(
              'Unable to display speech transcript',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateMessages(state) {
    // Add new final transcripts as chat messages
    if (state.lastTranscript != null &&
        state.lastTranscript!.isNotEmpty &&
        state.status != HermesStatus.listening && // Only add when finalized
        state.lastTranscript != _lastProcessedTranscript) {
      setState(() {
        _messages.add(
          TranscriptMessage(
            text: state.lastTranscript!,
            timestamp: DateTime.now(),
          ),
        );

        // Keep only last 50 messages to manage memory
        if (_messages.length > 50) {
          _messages.removeAt(0);
        }
      });

      _lastProcessedTranscript = state.lastTranscript;

      // Auto-scroll to bottom if user hasn't manually scrolled up
      if (!_userHasScrolledUp) {
        _scrollToBottom();
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

  String _formatTimestamp(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 10) {
      return 'Just now';
    } else if (difference.inMinutes < 1) {
      return '${difference.inSeconds}s ago';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Data model for transcript messages
class TranscriptMessage {
  final String text;
  final DateTime timestamp;

  const TranscriptMessage({required this.text, required this.timestamp});
}
