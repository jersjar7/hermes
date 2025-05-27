// lib/main.dart

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/theme/app_theme_dark.dart';
import 'package:hermes/core/theme/app_theme_light.dart';
import 'package:hermes/core/theme/theme_provider.dart';
import 'package:hermes/features/app/presentation/providers/app_router.dart';

import 'core/service_locator.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load from assets/env/.env in the asset bundle
  await dotenv.load(fileName: 'assets/env/.env');

  await Firebase.initializeApp();
  await setupServiceLocator();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'Hermes',
      theme: AppThemeLight.themeData,
      darkTheme: AppThemeDark.themeData,
      themeMode: themeMode,

      // 👇 Use the routerDelegate & routeInformationParser
      routerDelegate: appRouter.routerDelegate,
      routeInformationParser: appRouter.routeInformationParser,
      routeInformationProvider: appRouter.routeInformationProvider,

      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends ConsumerWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // To toggle theme, call:
    // ref.read(themeModeProvider.notifier).toggle();

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            onPressed: () => ref.read(themeModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text('You have pushed the button this many times:'),
            Text('0', style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}
