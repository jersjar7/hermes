// lib/features/app/presentation/widgets/hermes_app_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/theme/theme_provider.dart';
import 'package:hermes/core/services/navigation/back_navigation_service.dart';

/// A reusable AppBar with smart back navigation and theme toggle.
/// Automatically shows/hides back button based on current route and session state.
class HermesAppBar extends ConsumerWidget implements PreferredSizeWidget {
  /// Whether to force show the back button (overrides automatic detection)
  final bool? forceShowBack;

  /// Whether to force hide the back button (overrides automatic detection)
  final bool? forceHideBack;

  /// Custom title to override default "Hermes"
  final String? customTitle;

  /// Custom back navigation message for confirmation dialogs
  final String? customBackMessage;

  /// Custom back navigation title for confirmation dialogs
  final String? customBackTitle;

  const HermesAppBar({
    super.key,
    this.forceShowBack,
    this.forceHideBack,
    this.customTitle,
    this.customBackMessage,
    this.customBackTitle,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final shouldShowBack = _shouldShowBackButton(context);

    return AppBar(
      title: Text(customTitle ?? 'Hermes'),
      leading: shouldShowBack ? _buildBackButton(context, ref) : null,
      automaticallyImplyLeading: false, // We handle back button manually
      actions: [
        IconButton(
          icon: Icon(
            themeMode == ThemeMode.dark
                ? Icons.brightness_7
                : Icons.brightness_2,
          ),
          tooltip:
              themeMode == ThemeMode.dark
                  ? 'Switch to Light Mode'
                  : 'Switch to Dark Mode',
          onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
        ),
      ],
    );
  }

  /// Determines whether to show the back button
  bool _shouldShowBackButton(BuildContext context) {
    // Force overrides take precedence
    if (forceHideBack == true) return false;
    if (forceShowBack == true) return true;

    // Use automatic detection
    return context.shouldShowBackButton;
  }

  /// Builds the smart back button
  Widget _buildBackButton(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.arrow_back_rounded),
      tooltip: 'Back',
      onPressed: () => _handleBackPressed(context, ref),
    );
  }

  /// Handles back button press with smart navigation logic
  Future<void> _handleBackPressed(BuildContext context, WidgetRef ref) async {
    await context.smartGoBack(
      ref,
      customMessage: customBackMessage,
      customTitle: customBackTitle,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

/// Simplified version for pages that never need back navigation
class SimpleHermesAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final String? title;

  const SimpleHermesAppBar({super.key, this.title});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return AppBar(
      title: Text(title ?? 'Hermes'),
      automaticallyImplyLeading: false,
      actions: [
        IconButton(
          icon: Icon(
            themeMode == ThemeMode.dark
                ? Icons.brightness_7
                : Icons.brightness_2,
          ),
          tooltip:
              themeMode == ThemeMode.dark
                  ? 'Switch to Light Mode'
                  : 'Switch to Dark Mode',
          onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}
