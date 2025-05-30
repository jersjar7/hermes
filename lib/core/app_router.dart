// lib/features/app/presentation/providers/app_router.dart

import 'package:go_router/go_router.dart';
import 'package:hermes/features/app/presentation/pages/generic_error_page.dart';
import 'package:hermes/features/app/presentation/pages/home_page.dart';
import 'package:hermes/features/app/presentation/pages/splash_screen_page.dart';

/// Centralized router for Hermes App Shell
final GoRouter appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      name: 'splash',
      builder: (context, state) => const SplashScreenPage(),
    ),
    GoRoute(
      path: '/',
      name: 'home',
      builder: (context, state) => const HomePage(),
    ),
  ],

  // Error page
  errorBuilder:
      (context, state) =>
          GenericErrorPage(error: state.error, location: state.uri.toString()),
);
