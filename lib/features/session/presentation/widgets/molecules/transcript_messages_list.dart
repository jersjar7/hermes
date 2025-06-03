// lib/features/session/presentation/widgets/molecules/transcript_messages_list.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/durations.dart';
import 'package:hermes/core/presentation/widgets/animations/fade_in_widget.dart';
import '../atoms/transcript_message_bubble.dart';
import '../../utils/transcript_message.dart';

/// Scrollable list of transcript messages with scroll state tracking
class TranscriptMessagesList extends StatefulWidget {
  final List<TranscriptMessage> messages;
  final ScrollController scrollController;
  final ValueChanged<bool> onScrollStateChanged;

  const TranscriptMessagesList({
    super.key,
    required this.messages,
    required this.scrollController,
    required this.onScrollStateChanged,
  });

  @override
  State<TranscriptMessagesList> createState() => _TranscriptMessagesListState();
}

class _TranscriptMessagesListState extends State<TranscriptMessagesList> {
  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    if (!widget.scrollController.hasClients) return;

    final isAtBottom =
        widget.scrollController.offset >=
        widget.scrollController.position.maxScrollExtent - 50;

    widget.onScrollStateChanged(!isAtBottom);
  }

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(HermesSpacing.sm),
      itemCount: widget.messages.length,
      itemBuilder: (context, index) {
        final message = widget.messages[index];
        final isLatest = index == widget.messages.length - 1;

        return FadeInWidget(
          duration: HermesDurations.fast,
          slideFrom: const Offset(0, 0.2),
          child: TranscriptMessageBubble(message: message, isLatest: isLatest),
        );
      },
    );
  }
}
