// lib/features/session/presentation/widgets/organisms/recent_transcript_display.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/durations.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/core/presentation/widgets/animations/fade_in_widget.dart';

/// Displays recent transcript entries with expandable history.
/// Optimized for speakers to see their recent speech without clutter.
class RecentTranscriptDisplay extends StatefulWidget {
  final List<TranscriptEntry> entries;
  final int recentCount;
  final bool autoScroll;
  final VoidCallback? onClear;

  const RecentTranscriptDisplay({
    super.key,
    required this.entries,
    this.recentCount = 3,
    this.autoScroll = true,
    this.onClear,
  });

  @override
  State<RecentTranscriptDisplay> createState() =>
      _RecentTranscriptDisplayState();
}

class _RecentTranscriptDisplayState extends State<RecentTranscriptDisplay> {
  bool _isExpanded = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(RecentTranscriptDisplay oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-scroll to bottom when new entries are added
    if (widget.autoScroll &&
        widget.entries.length > oldWidget.entries.length &&
        _scrollController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: HermesDurations.fast,
          curve: Curves.easeOut,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (widget.entries.isEmpty) {
      return _buildEmptyState(context);
    }

    final displayedEntries =
        _isExpanded
            ? widget.entries
            : widget.entries.take(widget.recentCount).toList();

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
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          _buildHeader(context),

          // Transcript entries
          AnimatedContainer(
            duration: HermesDurations.normal,
            constraints: BoxConstraints(maxHeight: _isExpanded ? 400 : 200),
            child: ListView.builder(
              controller: _scrollController,
              shrinkWrap: true,
              padding: const EdgeInsets.all(HermesSpacing.sm),
              itemCount: displayedEntries.length,
              itemBuilder: (context, index) {
                final entry = displayedEntries[index];
                final isRecent =
                    index >= displayedEntries.length - widget.recentCount;

                return _TranscriptItem(
                  entry: entry,
                  isRecent: isRecent,
                  isFirst: index == 0,
                );
              },
            ),
          ),

          // Expand/Collapse button
          if (widget.entries.length > widget.recentCount)
            _buildExpandButton(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: HermesSpacing.md,
        vertical: HermesSpacing.sm,
      ),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            HermesIcons.microphone,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: HermesSpacing.xs),
          Text(
            _isExpanded ? 'Speech History' : 'Recent Speech',
            style: theme.textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          if (widget.entries.isNotEmpty)
            Text(
              '${widget.entries.length} entries',
              style: theme.textTheme.labelSmall?.copyWith(
                color: theme.colorScheme.outline,
              ),
            ),
          if (widget.onClear != null && widget.entries.isNotEmpty) ...[
            const SizedBox(width: HermesSpacing.sm),
            IconButton(
              icon: const Icon(Icons.clear_all_rounded),
              iconSize: 18,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              onPressed: widget.onClear,
              tooltip: 'Clear history',
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExpandButton(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: () => setState(() => _isExpanded = !_isExpanded),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: HermesSpacing.md,
          vertical: HermesSpacing.sm,
        ),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _isExpanded ? 'Show less' : 'Show all (${widget.entries.length})',
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: HermesSpacing.xs),
            Icon(
              _isExpanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
              color: theme.colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(HermesSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            HermesIcons.microphone,
            size: 32,
            color: theme.colorScheme.outline,
          ),
          const SizedBox(height: HermesSpacing.sm),
          Text(
            'Your speech will appear here',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );
  }
}

/// Individual transcript item
class _TranscriptItem extends StatelessWidget {
  final TranscriptEntry entry;
  final bool isRecent;
  final bool isFirst;

  const _TranscriptItem({
    required this.entry,
    required this.isRecent,
    required this.isFirst,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final widget = Container(
      margin: EdgeInsets.only(
        bottom: HermesSpacing.xs,
        top: isFirst ? 0 : HermesSpacing.xs,
      ),
      padding: const EdgeInsets.all(HermesSpacing.sm),
      decoration: BoxDecoration(
        color:
            isRecent
                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.1)
                : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(HermesSpacing.sm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            entry.text,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isRecent ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          const SizedBox(height: HermesSpacing.xs),
          Text(
            _formatTime(entry.timestamp),
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),
        ],
      ),
    );

    return isRecent
        ? FadeInWidget(duration: HermesDurations.fast, child: widget)
        : widget;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      final minutes = difference.inMinutes;
      return '$minutes ${minutes == 1 ? 'minute' : 'minutes'} ago';
    } else {
      return '${time.hour.toString().padLeft(2, '0')}:'
          '${time.minute.toString().padLeft(2, '0')}';
    }
  }
}

/// Data model for transcript entries
class TranscriptEntry {
  final String text;
  final DateTime timestamp;
  final bool isFinal;

  const TranscriptEntry({
    required this.text,
    required this.timestamp,
    this.isFinal = true,
  });
}
