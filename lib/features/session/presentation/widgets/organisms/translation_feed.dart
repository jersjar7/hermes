// lib/features/session/presentation/widgets/organisms/translation_feed.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';
import '../molecules/transcript_bubble.dart';

/// Translation feed for AUDIENCE MEMBERS ONLY.
/// Shows only translated content - speakers should use RecentTranscriptDisplay instead.
/// Focused on displaying translations in real-time for audience consumption.
class TranslationFeed extends ConsumerStatefulWidget {
  final bool autoScroll;
  final String? targetLanguageName;

  const TranslationFeed({
    super.key,
    this.autoScroll = true,
    this.targetLanguageName,
  });

  @override
  ConsumerState<TranslationFeed> createState() => _TranslationFeedState();
}

class _TranslationFeedState extends ConsumerState<TranslationFeed> {
  final ScrollController _scrollController = ScrollController();
  final List<_TranslationItem> _translations = [];
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

    // Important: This component should ONLY be used for audience members
    if (sessionService.isSpeaker) {
      return _buildSpeakerWarning(context);
    }

    return sessionState.when(
      data: (state) {
        _updateTranslations(state);

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
              _buildFeedHeader(context, state),

              // Translation content
              Expanded(
                child:
                    _translations.isEmpty
                        ? _buildEmptyState(context)
                        : _buildTranslationFeed(context),
              ),
            ],
          ),
        );
      },
      loading: () => _buildLoadingState(context),
      error: (error, _) => _buildErrorState(context, error),
    );
  }

  Widget _buildFeedHeader(BuildContext context, state) {
    final theme = Theme.of(context);
    final languageText = widget.targetLanguageName ?? 'your language';

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
            Icons.translate_rounded,
            size: 20,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: HermesSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Live Translation',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Translated to $languageText',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.outline,
                  ),
                ),
              ],
            ),
          ),
          if (_translations.isNotEmpty)
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
                '${_translations.length}',
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

  Widget _buildTranslationFeed(BuildContext context) {
    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(vertical: HermesSpacing.sm),
      itemCount: _translations.length,
      itemBuilder: (context, index) {
        final translation = _translations[index];

        return TranscriptBubble(
          text: translation.text,
          isTranslation: true,
          timestamp: translation.timestamp,
          isLoading: false,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(HermesSpacing.lg),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.translate_rounded,
              size: 64,
              color: theme.colorScheme.outline,
            ),
            const SizedBox(height: HermesSpacing.md),
            Text(
              'Waiting for translations',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
            const SizedBox(height: HermesSpacing.xs),
            Text(
              'Translations will appear here when the speaker begins talking',
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
            'Translation Error',
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
          const SizedBox(height: HermesSpacing.xs),
          Text(
            'Unable to receive translations',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpeakerWarning(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(HermesSpacing.lg),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              size: 48,
              color: theme.colorScheme.error,
            ),
            const SizedBox(height: HermesSpacing.md),
            Text(
              'Component Misuse',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.error,
              ),
            ),
            const SizedBox(height: HermesSpacing.xs),
            Text(
              'TranslationFeed is for audience members only.\nSpeakers should use RecentTranscriptDisplay.',
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

  void _updateTranslations(state) {
    // Only add translations when available and not already processed
    if (state.lastTranslation != null &&
        state.lastTranslation!.isNotEmpty &&
        state.lastTranslation != _lastProcessedTranslation) {
      print(
        '✅ [TranslationFeed] Adding translation: "${state.lastTranslation}"',
      );

      setState(() {
        _translations.add(
          _TranslationItem(
            text: state.lastTranslation!,
            timestamp: DateTime.now(),
          ),
        );

        // Keep only last 50 translations to manage memory
        if (_translations.length > 50) {
          _translations.removeAt(0);
        }
      });

      _lastProcessedTranslation = state.lastTranslation;

      // Auto-scroll to bottom if enabled
      if (widget.autoScroll && _scrollController.hasClients) {
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
    }
  }
}

/// Simple data model for translation items
class _TranslationItem {
  final String text;
  final DateTime timestamp;

  _TranslationItem({required this.text, required this.timestamp});
}

/// Compact version for smaller spaces (audience-only)
class CompactTranslationFeed extends ConsumerWidget {
  final String? targetLanguageName;
  final int maxVisibleItems;

  const CompactTranslationFeed({
    super.key,
    this.targetLanguageName,
    this.maxVisibleItems = 3,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionService = getIt<ISessionService>();

    // Only for audience members
    if (sessionService.isSpeaker) {
      return const SizedBox.shrink();
    }

    final sessionState = ref.watch(hermesControllerProvider);

    return sessionState.when(
      data: (state) {
        if (state.lastTranslation == null || state.lastTranslation!.isEmpty) {
          return const SizedBox.shrink();
        }

        return Container(
          padding: const EdgeInsets.all(HermesSpacing.md),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(HermesSpacing.md),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Latest Translation',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.outline,
                ),
              ),
              const SizedBox(height: HermesSpacing.xs),
              Text(
                state.lastTranslation!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}
