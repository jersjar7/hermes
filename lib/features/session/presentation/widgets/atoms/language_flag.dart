// lib/features/session/presentation/widgets/atoms/language_flag.dart

import 'package:flutter/material.dart';

/// Displays a language flag emoji with consistent sizing and fallback.
/// Used in language selectors and session displays.
class LanguageFlag extends StatelessWidget {
  final String flag;
  final double size;
  final bool showBorder;

  const LanguageFlag({
    super.key,
    required this.flag,
    this.size = 24.0,
    this.showBorder = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: size,
      height: size,
      decoration:
          showBorder
              ? BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: theme.colorScheme.outline.withValues(alpha: 0.2),
                  width: 1,
                ),
              )
              : null,
      child: Center(
        child:
            flag.isNotEmpty
                ? Text(
                  flag,
                  style: TextStyle(fontSize: size * 0.7),
                  textAlign: TextAlign.center,
                )
                : Icon(
                  Icons.language_rounded,
                  size: size * 0.6,
                  color: theme.colorScheme.outline,
                ),
      ),
    );
  }
}
