// lib/features/session/presentation/widgets/organisms/translation_feed.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';
import '../molecules/transcript_bubble.dart';

/// Scrollable feed of transcripts and translations during active sessions.
/// Shows conversation history with original text and translated versions.
class TranslationFeed extends ConsumerStatefulWidget {
  final bool showOriginalText;
  final bool autoScroll;

  const TranslationFeed({
    super.key,
    this.showOriginalText = true,
    this.autoScroll = true,
  });

  @override
  ConsumerState<TranslationFeed> createState() => _TranslationFeedState();
}

class _TranslationFeedState extends ConsumerState<TranslationFeed> {
  final ScrollController _scrollController = ScrollController();
  final List<_FeedItem> _feedItems = [];
  String? _lastProcessedTranscript;
  String? _lastProcessedTranslation;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(hermesControllerProvider);
    final sessionService = getIt<ISessionService>();
    final isSpeaker = sessionService.isSpeaker;

    return sessionState.when(
      data: (state) {
        _updateFeedItems(state, isSpeaker);

        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(HermesSpacing.md),
            ),
          ),
          child: Column(
            children: [
              // Feed header
              _buildFeedHeader(context, state, isSpeaker),

              // Feed content
              Expanded(
                child:
                    _feedItems.isEmpty
                        ? _buildEmptyState(context, isSpeaker)
                        : _buildFeed(context),
              ),
            ],
          ),
        );
      },
      loading: () => _buildLoadingState(context),
      error: (error, _) => _buildErrorState(context, error),
    );
  }

  Widget _buildFeedHeader(BuildContext context, state, bool isSpeaker) {
    final theme = Theme.of(context);
    final title =
        isSpeaker ? 'Speech & Translation History' : 'Translation History';

    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withOpacity(0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 20,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(width: HermesSpacing.sm),
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              color: theme.colorScheme.outline,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (_feedItems.isNotEmpty)
            Text(
              '${_feedItems.length} messages',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFeed(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: HermesSpacing.sm),
      itemCount: _feedItems.length,
      itemBuilder: (context, index) {
        final item = _feedItems[index];
        return TranscriptBubble(
          text: item.text,
          isTranslation: item.isTranslation,
          timestamp: item.timestamp,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isSpeaker) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HermesSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.mic_none_rounded,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: HermesSpacing.md),
            Text(
              isSpeaker
                  ? 'Start speaking to see your words'
                  : 'Waiting for translations',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: HermesSpacing.xs),
            Text(
              isSpeaker
                  ? 'Your speech and translations will appear here'
                  : 'Translated content will appear here in real-time',
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
    return const Center(child: CircularProgressIndicator());
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: theme.colorScheme.error),
          const SizedBox(height: HermesSpacing.md),
          Text(
            'Feed Error',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
      ),
    );
  }

  void _updateFeedItems(state, bool isSpeaker) {
    final now = DateTime.now();
    bool shouldScroll = false;

    print('🔄 [TranslationFeed] Updating feed items');
    print('   Last transcript: "${state.lastTranscript}"');
    print('   Last translation: "${state.lastTranslation}"');
    print('   Current status: ${state.status}');
    print('   Is speaker: $isSpeaker');

    // For speakers: Add transcripts when they're available (even partial ones for real-time feedback)
    if (isSpeaker &&
        state.lastTranscript != null &&
        state.lastTranscript!.isNotEmpty &&
        state.lastTranscript != _lastProcessedTranscript) {
      // For speakers, show their speech in real-time, but only add to history when it's substantial
      if (state.lastTranscript!.length > 10) {
        // Only add if transcript is substantial
        print(
          '✅ [TranslationFeed] Adding speaker transcript: "${state.lastTranscript}"',
        );

        // Remove previous transcript if it was just updated (real-time editing)
        if (_feedItems.isNotEmpty &&
            !_feedItems.last.isTranslation &&
            _lastProcessedTranscript != null &&
            state.lastTranscript!.startsWith(_lastProcessedTranscript!)) {
          _feedItems.removeLast();
        }

        _feedItems.add(
          _FeedItem(
            text: state.lastTranscript!,
            isTranslation: false,
            timestamp: now,
          ),
        );
        _lastProcessedTranscript = state.lastTranscript;
        shouldScroll = true;
      }
    }

    // For both speakers and audience: Add translations when available
    if (state.lastTranslation != null &&
        state.lastTranslation!.isNotEmpty &&
        state.lastTranslation != _lastProcessedTranslation) {
      print(
        '✅ [TranslationFeed] Adding translation: "${state.lastTranslation}"',
      );
      _feedItems.add(
        _FeedItem(
          text: state.lastTranslation!,
          isTranslation: true,
          timestamp: now,
        ),
      );
      _lastProcessedTranslation = state.lastTranslation;
      shouldScroll = true;
    }

    // Auto-scroll to bottom if enabled and new items added
    if (shouldScroll && widget.autoScroll && _scrollController.hasClients) {
      print('📜 [TranslationFeed] Auto-scrolling to bottom');
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

    print('📋 [TranslationFeed] Feed now has ${_feedItems.length} items');
  }
}

class _FeedItem {
  final String text;
  final bool isTranslation;
  final DateTime timestamp;

  _FeedItem({
    required this.text,
    required this.isTranslation,
    required this.timestamp,
  });
}
