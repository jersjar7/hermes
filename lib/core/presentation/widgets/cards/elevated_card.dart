// lib/core/presentation/widgets/cards/elevated_card.dart

import 'package:flutter/material.dart';
import '../../constants/spacing.dart';

/// Material Design 3 elevated card with subtle shadow.
/// Supports tap interactions and custom elevation.
class ElevatedCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final double elevation;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? backgroundColor;

  const ElevatedCard({
    super.key,
    required this.child,
    this.onTap,
    this.elevation = 2.0,
    this.padding,
    this.margin,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: margin ?? const EdgeInsets.all(HermesSpacing.sm),
      child: Material(
        elevation: elevation,
        borderRadius: BorderRadius.circular(12),
        color: backgroundColor ?? theme.cardColor,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: padding ?? const EdgeInsets.all(HermesSpacing.cardPadding),
            child: child,
          ),
        ),
      ),
    );
  }
}
