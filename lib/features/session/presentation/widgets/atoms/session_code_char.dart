// lib/features/session/presentation/widgets/atoms/session_code_char.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/durations.dart';

/// Displays a single character of a session code with styling.
/// Supports empty state, error state, and smooth transitions.
class SessionCodeChar extends StatelessWidget {
  final String? character;
  final bool isActive;
  final bool hasError;

  const SessionCodeChar({
    super.key,
    this.character,
    this.isActive = false,
    this.hasError = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AnimatedContainer(
      duration: HermesDurations.fast,
      width: 40,
      height: 50,
      decoration: BoxDecoration(
        color: _getBackgroundColor(theme),
        border: Border.all(
          color: _getBorderColor(theme),
          width: isActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(HermesSpacing.sm),
      ),
      child: Center(
        child: AnimatedSwitcher(
          duration: HermesDurations.fast,
          child: Text(
            character ?? '',
            key: ValueKey(character),
            style: theme.textTheme.titleLarge?.copyWith(
              color: _getTextColor(theme),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Color _getBackgroundColor(ThemeData theme) {
    if (hasError) return theme.colorScheme.errorContainer;
    if (isActive) return theme.colorScheme.primaryContainer;
    return theme.colorScheme.surface;
  }

  Color _getBorderColor(ThemeData theme) {
    if (hasError) return theme.colorScheme.error;
    if (isActive) return theme.colorScheme.primary;
    return theme.colorScheme.outline;
  }

  Color _getTextColor(ThemeData theme) {
    if (hasError) return theme.colorScheme.onErrorContainer;
    return theme.colorScheme.onSurface;
  }
}
