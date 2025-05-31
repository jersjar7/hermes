// lib/features/session/presentation/widgets/organisms/translation_feed.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
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

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final sessionState = ref.watch(hermesControllerProvider);

    return sessionState.when(
      data: (state) {
        _updateFeedItems(state);

        return _feedItems.isEmpty
            ? _buildEmptyState(context)
            : _buildFeed(context);
      },
      loading: () => _buildLoadingState(context),
      error: (error, _) => _buildErrorState(context, error),
    );
  }

  Widget _buildFeed(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(HermesSpacing.md),
        ),
      ),
      child: ListView.builder(
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
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 64,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: HermesSpacing.md),
          Text(
            'Conversation will appear here',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
          const SizedBox(height: HermesSpacing.xs),
          Text(
            'Start speaking to see translations',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
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

  void _updateFeedItems(state) {
    final now = DateTime.now();

    // Add new transcript if available
    if (state.lastTranscript != null &&
        !_hasRecentItem(state.lastTranscript!, false)) {
      if (widget.showOriginalText) {
        _feedItems.add(
          _FeedItem(
            text: state.lastTranscript!,
            isTranslation: false,
            timestamp: now,
          ),
        );
      }
    }

    // Add new translation if available
    if (state.lastTranslation != null &&
        !_hasRecentItem(state.lastTranslation!, true)) {
      _feedItems.add(
        _FeedItem(
          text: state.lastTranslation!,
          isTranslation: true,
          timestamp: now,
        ),
      );
    }

    // Auto-scroll to bottom if enabled
    if (widget.autoScroll && _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      });
    }
  }

  bool _hasRecentItem(String text, bool isTranslation) {
    return _feedItems.any(
      (item) =>
          item.text == text &&
          item.isTranslation == isTranslation &&
          DateTime.now().difference(item.timestamp).inSeconds < 2,
    );
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
