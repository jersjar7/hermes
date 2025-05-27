// lib/features/app/presentation/widgets/hermes_app_bar.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/theme/theme_provider.dart';

/// A reusable AppBar that shows the app title and a theme toggle button.
class HermesAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const HermesAppBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the current theme mode (light/dark)
    final themeMode = ref.watch(themeModeProvider);

    return AppBar(
      title: const Text('Hermes'),
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
