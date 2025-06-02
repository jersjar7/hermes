// lib/features/session/presentation/widgets/organisms/transcript_chat_box.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/core/presentation/constants/durations.dart';
import 'package:hermes/core/presentation/widgets/animations/fade_in_widget.dart';
import 'package:hermes/core/presentation/widgets/animations/pulse_animation.dart';

/// Enhanced chat-like transcript box that displays speaker's speech in real-time.
/// Features elegant empty states and smooth animations.
class TranscriptChatBox extends ConsumerStatefulWidget {
  const TranscriptChatBox({super.key});

  @override
  ConsumerState<TranscriptChatBox> createState() => _TranscriptChatBoxState();
}

class _TranscriptChatBoxState extends ConsumerState<TranscriptChatBox> {
  final ScrollController _scrollController = ScrollController();
  final List<TranscriptMessage> _messages = [];
  String? _lastProcessedTranscript;
  String? _currentPartialTranscript;
  bool _userHasScrolledUp = false;
  bool _showScrollToBottomButton = false;
  bool _hasEverSpoken = false;

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
          _updateTranscripts(state);

          return Column(
            children: [
              // Header with dynamic status
              _buildHeader(context, theme, state),

              // Messages area - always visible
              Expanded(
                child: Stack(
                  children: [
                    _buildMessagesArea(context, theme, state),
                    if (_showScrollToBottomButton)
                      _buildScrollToBottomButton(context, theme),
                  ],
                ),
              ),

              // Current speaking indicator
              _buildCurrentSpeechIndicator(context, theme, state),
            ],
          );
        },
        loading: () => _buildLoadingState(context, theme),
        error: (error, _) => _buildErrorState(context, theme, error),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, ThemeData theme, state) {
    final isListening = state.status == HermesStatus.listening;
    final isTranslating = state.status == HermesStatus.translating;
    final hasActivity = isListening || isTranslating || _messages.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        color:
            hasActivity
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.1)
                : null,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(HermesSpacing.md),
        ),
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Dynamic icon with subtle animation
          PulseAnimation(
            animate: isListening,
            minScale: 0.95,
            maxScale: 1.05,
            child: Icon(
              _getHeaderIcon(state.status),
              size: 20,
              color:
                  hasActivity
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outline,
            ),
          ),
          const SizedBox(width: HermesSpacing.sm),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getHeaderTitle(state.status, _hasEverSpoken),
                  style: theme.textTheme.titleSmall?.copyWith(
                    color:
                        hasActivity
                            ? theme.colorScheme.primary
                            : theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  _getHeaderSubtitle(state.status, _hasEverSpoken),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),

          // Status indicator
          _buildStatusIndicator(context, theme, state),
        ],
      ),
    );
  }

  Widget _buildStatusIndicator(BuildContext context, ThemeData theme, state) {
    final isListening = state.status == HermesStatus.listening;

    if (_messages.isNotEmpty) {
      // Show message count
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HermesSpacing.sm,
          vertical: HermesSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '${_messages.length}',
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w600,
          ),
        ),
      );
    } else if (isListening) {
      // Show live indicator
      return Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HermesSpacing.sm,
          vertical: HermesSpacing.xs,
        ),
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.red.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PulseAnimation(
              animate: true,
              child: Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 4),
            Text(
              'LIVE',
              style: theme.textTheme.labelSmall?.copyWith(
                color: Colors.red.shade700,
                fontWeight: FontWeight.w800,
                fontSize: 10,
              ),
            ),
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMessagesArea(BuildContext context, ThemeData theme, state) {
    if (_messages.isEmpty) {
      return _buildEmptyState(context, theme, state);
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

  Widget _buildEmptyState(BuildContext context, ThemeData theme, state) {
    final isReady =
        state.status == HermesStatus.listening ||
        state.status == HermesStatus.buffering;
    final isListening = state.status == HermesStatus.listening;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HermesSpacing.xl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Elegant microphone icon
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withValues(
                  alpha: 0.2,
                ),
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.primary.withValues(alpha: 0.2),
                  width: 1,
                ),
              ),
              child: Icon(
                isListening ? HermesIcons.listening : HermesIcons.microphone,
                size: 28,
                color: theme.colorScheme.primary.withValues(alpha: 0.7),
              ),
            ),

            const SizedBox(height: HermesSpacing.lg),

            Text(
              _getEmptyStateTitle(state.status, _hasEverSpoken),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: HermesSpacing.sm),

            Text(
              _getEmptyStateSubtitle(state.status, _hasEverSpoken),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.outline,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),

            // Subtle speaking tips for new sessions
            if (!_hasEverSpoken && isReady) ...[
              const SizedBox(height: HermesSpacing.xl),
              _buildSpeakingTips(theme),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSpeakingTips(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(HermesSpacing.sm),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 16,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(width: HermesSpacing.xs),
              Text(
                'Speaking Tips',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.outline,
                ),
              ),
            ],
          ),
          const SizedBox(height: HermesSpacing.sm),
          ...[
            'Speak clearly at a normal pace',
            'Pause briefly between sentences',
            'Keep device 6-12 inches away',
          ].map((tip) => _buildTip(tip, theme)),
        ],
      ),
    );
  }

  Widget _buildTip(String text, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.only(top: HermesSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: 3,
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: theme.colorScheme.outline.withValues(alpha: 0.6),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: HermesSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          ),
        ],
      ),
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
          // Avatar
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
                              alpha: 0.2,
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
                                alpha: 0.2,
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
                      height: 1.4,
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
    state,
  ) {
    final isListening = state.status == HermesStatus.listening;
    final isTranslating = state.status == HermesStatus.translating;
    final hasCurrentSpeech =
        _currentPartialTranscript != null &&
        _currentPartialTranscript!.isNotEmpty;

    if (!isListening && !isTranslating && !hasCurrentSpeech) {
      return const SizedBox.shrink();
    }

    return AnimatedContainer(
      duration: HermesDurations.fast,
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.1),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(HermesSpacing.md),
        ),
        border: Border(
          top: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // Live indicator
          PulseAnimation(
            animate: isListening,
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: isListening ? Colors.red : Colors.amber,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: HermesSpacing.sm),

          // Status text
          Text(
            isListening ? 'Listening: ' : 'Processing: ',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),

          // Current text or placeholder
          Expanded(
            child:
                hasCurrentSpeech
                    ? ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 60),
                      child: SingleChildScrollView(
                        child: Text(
                          _currentPartialTranscript!,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.primary,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    )
                    : Text(
                      isListening
                          ? 'Start speaking...'
                          : 'Converting to text...',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.outline,
                        fontStyle: FontStyle.italic,
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
        elevation: 2,
        child: const Icon(Icons.keyboard_arrow_down_rounded),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context, ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(strokeWidth: 2),
          const SizedBox(height: HermesSpacing.md),
          Text(
            'Initializing transcript...',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
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
            Text(
              'Unable to display speech transcript',
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

  void _updateTranscripts(state) {
    final currentTranscript = state.lastTranscript;
    final isListening = state.status == HermesStatus.listening;
    final isTranslating = state.status == HermesStatus.translating;

    // Track if user has ever spoken
    if (currentTranscript != null && currentTranscript.isNotEmpty) {
      _hasEverSpoken = true;
    }

    // Handle partial transcripts (during listening)
    if (isListening &&
        currentTranscript != null &&
        currentTranscript.isNotEmpty) {
      setState(() {
        _currentPartialTranscript = currentTranscript;
      });
    }
    // Handle final transcripts
    else if (currentTranscript != null &&
        currentTranscript.isNotEmpty &&
        currentTranscript != _lastProcessedTranscript &&
        !isListening) {
      setState(() {
        _messages.add(
          TranscriptMessage(text: currentTranscript, timestamp: DateTime.now()),
        );

        _currentPartialTranscript = null;

        // Keep only last 50 messages
        if (_messages.length > 50) {
          _messages.removeAt(0);
        }
      });

      _lastProcessedTranscript = currentTranscript;

      // Auto-scroll if user hasn't manually scrolled
      if (!_userHasScrolledUp) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _scrollToBottom();
        });
      }
    }
    // Clear partial transcript when not listening
    else if (!isListening && !isTranslating) {
      setState(() {
        _currentPartialTranscript = null;
      });
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

  IconData _getHeaderIcon(HermesStatus status) {
    switch (status) {
      case HermesStatus.listening:
        return HermesIcons.listening;
      case HermesStatus.translating:
        return HermesIcons.translating;
      default:
        return HermesIcons.microphone;
    }
  }

  String _getHeaderTitle(HermesStatus status, bool hasEverSpoken) {
    switch (status) {
      case HermesStatus.listening:
        return 'Listening Live';
      case HermesStatus.translating:
        return 'Processing Speech';
      case HermesStatus.buffering:
        return hasEverSpoken ? 'Speech History' : 'Speech Transcript';
      default:
        return hasEverSpoken ? 'Speech History' : 'Ready to Listen';
    }
  }

  String _getHeaderSubtitle(HermesStatus status, bool hasEverSpoken) {
    switch (status) {
      case HermesStatus.listening:
        return 'Your speech appears here in real-time';
      case HermesStatus.translating:
        return 'Converting speech to text...';
      case HermesStatus.buffering:
        return hasEverSpoken
            ? 'Your recent speech messages'
            : 'Start speaking to see your words here';
      default:
        return hasEverSpoken
            ? 'Your speech messages from this session'
            : 'Start speaking when you\'re ready';
    }
  }

  String _getEmptyStateTitle(HermesStatus status, bool hasEverSpoken) {
    if (hasEverSpoken) {
      return 'No recent messages';
    }

    switch (status) {
      case HermesStatus.listening:
        return 'Start speaking';
      case HermesStatus.buffering:
        return 'Ready to listen';
      default:
        return 'Welcome to your session';
    }
  }

  String _getEmptyStateSubtitle(HermesStatus status, bool hasEverSpoken) {
    if (hasEverSpoken) {
      return 'Your speech messages will appear here when you start talking';
    }

    switch (status) {
      case HermesStatus.listening:
        return 'Your words will appear here as you speak';
      case HermesStatus.buffering:
        return 'Getting ready to capture your speech';
      default:
        return 'Your speech will be displayed here as you talk, creating a real-time transcript for this session';
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
