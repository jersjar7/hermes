// lib/features/session/presentation/widgets/molecules/current_speech_indicator.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/durations.dart';

/// Indicator showing current speech being processed with auto-scrolling text
class CurrentSpeechIndicator extends StatefulWidget {
  final HermesStatus status;
  final String? currentText;

  const CurrentSpeechIndicator({
    super.key,
    required this.status,
    this.currentText,
  });

  @override
  State<CurrentSpeechIndicator> createState() => _CurrentSpeechIndicatorState();
}

class _CurrentSpeechIndicatorState extends State<CurrentSpeechIndicator> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(CurrentSpeechIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Auto-scroll to bottom when text updates
    if (widget.currentText != oldWidget.currentText &&
        widget.currentText?.isNotEmpty == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isListening = widget.status == HermesStatus.listening;
    final isTranslating = widget.status == HermesStatus.translating;
    final hasCurrentSpeech =
        widget.currentText != null && widget.currentText!.isNotEmpty;

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
          // Status indicator
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isListening ? Colors.green : Colors.amber,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: HermesSpacing.sm),

          // Current text with auto-scrolling
          Expanded(
            child:
                hasCurrentSpeech
                    ? Container(
                      height: 60, // Fixed height prevents UI jumping
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(HermesSpacing.xs),
                        border: Border.all(
                          color: theme.colorScheme.primary.withValues(
                            alpha: 0.2,
                          ),
                          width: 1,
                        ),
                      ),
                      child: Scrollbar(
                        controller: _scrollController,
                        thumbVisibility: true,
                        child: SingleChildScrollView(
                          controller: _scrollController,
                          padding: const EdgeInsets.all(HermesSpacing.sm),
                          child: Text(
                            widget.currentText!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.primary,
                              fontStyle: FontStyle.italic,
                              height: 1.4,
                            ),
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
}
