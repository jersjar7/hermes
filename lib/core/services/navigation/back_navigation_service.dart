// lib/core/services/navigation/back_navigation_service.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';

/// Service to handle smart back navigation with session-aware confirmations
class BackNavigationService {
  // Prevent instantiation
  BackNavigationService._();

  /// Handles back navigation with context-aware confirmation
  /// Returns true if navigation should proceed, false if canceled
  static Future<bool> handleBackNavigation({
    required BuildContext context,
    required WidgetRef ref,
    String? customMessage,
    String? customTitle,
  }) async {
    final route = GoRouterState.of(context);
    final currentPath = route.fullPath;

    // Check if we're in an active session that needs confirmation
    if (_requiresSessionConfirmation(currentPath)) {
      return await _showSessionExitConfirmation(
        context: context,
        ref: ref,
        customMessage: customMessage,
        customTitle: customTitle,
      );
    }

    // For other pages, navigate back directly
    return true;
  }

  /// Determines if the current page requires session confirmation before exit
  static bool _requiresSessionConfirmation(String? currentPath) {
    if (currentPath == null) return false;

    // Paths that require confirmation when there's an active session
    const sessionPaths = [
      '/active-session',
      '/host', // When in active speaking mode
    ];

    return sessionPaths.any((path) => currentPath.startsWith(path));
  }

  /// Shows confirmation dialog for exiting active sessions
  static Future<bool> _showSessionExitConfirmation({
    required BuildContext context,
    required WidgetRef ref,
    String? customMessage,
    String? customTitle,
  }) async {
    final sessionService = getIt<ISessionService>();
    final sessionState = ref.read(hermesControllerProvider);

    // Check if there's actually an active session
    final hasActiveSession = sessionState.when(
      data: (state) => _isSessionActive(state.status),
      loading: () => false,
      error: (_, __) => false,
    );

    // If no active session, just navigate back
    if (!hasActiveSession) return true;

    // Determine the appropriate message based on user role
    final isSpeaker = sessionService.isSpeaker;
    final defaultTitle = isSpeaker ? 'End Session' : 'Leave Session';
    final defaultMessage =
        isSpeaker
            ? 'Are you sure you want to end this session? All audience members will be disconnected.'
            : 'Are you sure you want to leave this session?';

    return await _showConfirmationDialog(
      context: context,
      title: customTitle ?? defaultTitle,
      message: customMessage ?? defaultMessage,
      confirmText: defaultTitle,
      ref: ref,
    );
  }

  /// Checks if the session status indicates an active session
  static bool _isSessionActive(HermesStatus status) {
    switch (status) {
      case HermesStatus.listening:
      case HermesStatus.translating:
      case HermesStatus.buffering:
      case HermesStatus.countdown:
      case HermesStatus.speaking:
      case HermesStatus.paused:
        return true;
      case HermesStatus.idle:
      case HermesStatus.error:
        return false;
    }
  }

  /// Shows a confirmation dialog and handles session cleanup if confirmed
  static Future<bool> _showConfirmationDialog({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    required WidgetRef ref,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                child: Text(confirmText),
              ),
            ],
          ),
    );

    // If confirmed, clean up the session
    if (confirmed == true) {
      try {
        await ref.read(hermesControllerProvider.notifier).stop();
      } catch (e) {
        debugPrint('Error stopping session during navigation: $e');
        // Continue with navigation even if cleanup fails
      }
    }

    return confirmed ?? false;
  }

  /// Determines if a back button should be shown for the current route
  static bool shouldShowBackButton(String? currentPath) {
    if (currentPath == null) return false;

    // Don't show back button on these routes
    const noBackButtonRoutes = [
      '/splash',
      '/', // Home page
    ];

    return !noBackButtonRoutes.contains(currentPath);
  }

  /// Gets the appropriate back navigation destination
  static String getBackDestination(String? currentPath) {
    if (currentPath == null) return '/';

    // Define navigation hierarchy
    const navigationMap = {
      '/host': '/',
      '/join': '/',
      '/active-session': '/', // Will go through confirmation
    };

    return navigationMap[currentPath] ?? '/';
  }
}

/// Provider for checking if back button should be shown
final showBackButtonProvider = Provider<bool>((ref) {
  // This would need to be updated when route changes
  // For now, we'll handle this in the AppBar directly
  return false;
});

/// Extension to add convenience methods to GoRouter context
extension BackNavigationExtension on BuildContext {
  /// Smart back navigation that respects session state
  Future<void> smartGoBack(
    WidgetRef ref, {
    String? customMessage,
    String? customTitle,
  }) async {
    final shouldNavigate = await BackNavigationService.handleBackNavigation(
      context: this,
      ref: ref,
      customMessage: customMessage,
      customTitle: customTitle,
    );

    if (shouldNavigate && mounted) {
      final currentPath = GoRouterState.of(this).fullPath;
      final destination = BackNavigationService.getBackDestination(currentPath);
      go(destination);
    }
  }

  /// Check if current route should show back button
  bool get shouldShowBackButton {
    final currentPath = GoRouterState.of(this).fullPath;
    return BackNavigationService.shouldShowBackButton(currentPath);
  }
}
