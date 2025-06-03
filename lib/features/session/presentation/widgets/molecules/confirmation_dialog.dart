// lib/features/session/presentation/widgets/molecules/confirmation_dialog.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/widgets/buttons/ghost_button.dart';

/// A standardized confirmation dialog for destructive or important actions.
/// Returns true if confirmed, false if canceled, null if dismissed.
class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmText;
  final String cancelText;
  final IconData? icon;
  final bool isDestructive;
  final List<String>? bulletPoints;
  final Widget? additionalInfo;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmText,
    this.cancelText = 'Cancel',
    this.icon,
    this.isDestructive = false,
    this.bulletPoints,
    this.additionalInfo,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(HermesSpacing.md),
      ),
      title: _buildTitle(theme),
      content: _buildContent(theme),
      actions: _buildActions(context),
    );
  }

  Widget _buildTitle(ThemeData theme) {
    if (icon != null) {
      return Row(
        children: [
          Icon(
            icon,
            color:
                isDestructive
                    ? theme.colorScheme.error
                    : theme.colorScheme.primary,
            size: 24,
          ),
          const SizedBox(width: HermesSpacing.sm),
          Text(title),
        ],
      );
    }
    return Text(title);
  }

  Widget _buildContent(ThemeData theme) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main message
          Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),

          // Bullet points
          if (bulletPoints != null && bulletPoints!.isNotEmpty) ...[
            const SizedBox(height: HermesSpacing.md),
            Text('This will:', style: theme.textTheme.bodyMedium),
            const SizedBox(height: HermesSpacing.xs),
            ...bulletPoints!.map(
              (point) => Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text('• $point'),
              ),
            ),
          ],

          // Additional info widget
          if (additionalInfo != null) ...[
            const SizedBox(height: HermesSpacing.md),
            additionalInfo!,
          ],
        ],
      ),
    );
  }

  List<Widget> _buildActions(BuildContext context) {
    return [
      GhostButton(
        label: cancelText,
        onPressed: () => Navigator.of(context).pop(false),
      ),
      GhostButton(
        label: confirmText,
        isDestructive: isDestructive,
        onPressed: () => Navigator.of(context).pop(true),
      ),
    ];
  }

  /// Shows the confirmation dialog and returns the result
  static Future<bool?> show({
    required BuildContext context,
    required String title,
    required String message,
    required String confirmText,
    String cancelText = 'Cancel',
    IconData? icon,
    bool isDestructive = false,
    List<String>? bulletPoints,
    Widget? additionalInfo,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => ConfirmationDialog(
            title: title,
            message: message,
            confirmText: confirmText,
            cancelText: cancelText,
            icon: icon,
            isDestructive: isDestructive,
            bulletPoints: bulletPoints,
            additionalInfo: additionalInfo,
          ),
    );
  }
}

/// Specialized confirmation dialog for ending sessions
class EndSessionDialog extends StatelessWidget {
  final int audienceCount;

  const EndSessionDialog({super.key, required this.audienceCount});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bulletPoints = [
      'Stop all translation services',
      if (audienceCount > 0) 'Disconnect $audienceCount audience members',
      'Delete the session permanently',
    ];

    final additionalInfo = Container(
      padding: const EdgeInsets.all(HermesSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(HermesSpacing.sm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: theme.colorScheme.error,
          ),
          const SizedBox(width: HermesSpacing.xs),
          Expanded(
            child: Text(
              'This action cannot be undone.',
              style: TextStyle(
                color: theme.colorScheme.error,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );

    return ConfirmationDialog(
      title: 'End Session',
      message: 'Are you sure you want to end this session?',
      confirmText: 'End Session',
      icon: Icons.warning_amber_rounded,
      isDestructive: true,
      bulletPoints: bulletPoints,
      additionalInfo: additionalInfo,
    );
  }

  /// Shows the end session dialog and returns the result
  static Future<bool?> show({
    required BuildContext context,
    required int audienceCount,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => EndSessionDialog(audienceCount: audienceCount),
    );
  }
}

/// Specialized confirmation dialog for leaving sessions
class LeaveSessionDialog extends StatelessWidget {
  const LeaveSessionDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bulletPoints = [
      'Stop receiving live translations',
      'Be disconnected from the speaker',
      'Need a new session code to rejoin',
    ];

    final additionalInfo = Container(
      padding: const EdgeInsets.all(HermesSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(HermesSpacing.sm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline_rounded,
            size: 16,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: HermesSpacing.xs),
          Expanded(
            child: Text(
              'The session will continue for other listeners.',
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );

    return ConfirmationDialog(
      title: 'Leave Session',
      message: 'Are you sure you want to leave this session?',
      confirmText: 'Leave Session',
      icon: Icons.exit_to_app_rounded,
      isDestructive: true,
      bulletPoints: bulletPoints,
      additionalInfo: additionalInfo,
    );
  }

  /// Shows the leave session dialog and returns the result
  static Future<bool?> show({required BuildContext context}) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const LeaveSessionDialog(),
    );
  }
}
