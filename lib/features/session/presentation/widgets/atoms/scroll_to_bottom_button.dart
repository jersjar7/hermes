// lib/features/session/presentation/widgets/atoms/scroll_to_bottom_button.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';

/// Floating action button for scrolling to bottom of transcript
class ScrollToBottomButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isVisible;

  const ScrollToBottomButton({
    super.key,
    required this.onPressed,
    this.isVisible = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (!isVisible) {
      return const SizedBox.shrink();
    }

    return Positioned(
      bottom: HermesSpacing.md,
      right: HermesSpacing.md,
      child: SizedBox(
        width: 48,
        height: 48,
        child: FloatingActionButton(
          onPressed: onPressed,
          backgroundColor: theme.colorScheme.primary,
          foregroundColor: theme.colorScheme.onPrimary,
          elevation: 2,
          mini: true,
          child: const Icon(Icons.keyboard_arrow_down_rounded, size: 20),
        ),
      ),
    );
  }
}
