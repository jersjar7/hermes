// lib/features/session/presentation/widgets/molecules/session_code_display.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import '../atoms/session_code_char.dart';

/// Displays a complete 6-character session code using SessionCodeChar atoms.
/// Supports input state, validation errors, and formatted display.
class SessionCodeDisplay extends StatelessWidget {
  final String code;
  final bool hasError;
  final int? activeIndex;
  final bool showFormatted;

  const SessionCodeDisplay({
    super.key,
    required this.code,
    this.hasError = false,
    this.activeIndex,
    this.showFormatted = true,
  });

  @override
  Widget build(BuildContext context) {
    final paddedCode = code.padRight(6, ' ');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 0; i < 6; i++) ...[
          SessionCodeChar(
            character: paddedCode[i] == ' ' ? null : paddedCode[i],
            isActive: activeIndex == i,
            hasError: hasError && code.length > i,
          ),
          if (i == 2 && showFormatted) const SizedBox(width: HermesSpacing.md),
          if (i != 2 && i != 5) const SizedBox(width: HermesSpacing.xs),
        ],
      ],
    );
  }
}
