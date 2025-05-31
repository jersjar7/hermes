// lib/features/session/presentation/widgets/organisms/session_join_form.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';
import 'package:hermes/core/presentation/widgets/buttons/primary_button.dart';
import 'package:hermes/core/presentation/widgets/cards/elevated_card.dart';
import 'package:hermes/features/session/presentation/controllers/session_code_input_controller.dart';
import '../molecules/session_code_display.dart';

/// Complete form for joining sessions with code input and validation.
/// Handles session code entry, validation, and join action.
class SessionJoinForm extends ConsumerWidget {
  final VoidCallback? onJoin;
  final bool isLoading;

  const SessionJoinForm({super.key, this.onJoin, this.isLoading = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final codeState = ref.watch(sessionCodeInputProvider);
    final theme = Theme.of(context);

    return ElevatedCard(
      padding: const EdgeInsets.all(HermesSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            'Join Session',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: HermesSpacing.xs),

          Text(
            'Enter the 6-character session code',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.outline,
            ),
          ),

          const SizedBox(height: HermesSpacing.lg),

          // Session code input
          _buildCodeInput(context, ref, codeState),

          const SizedBox(height: HermesSpacing.md),

          // Error message
          if (codeState.shouldShowError)
            _buildErrorMessage(context, codeState.error!),

          const SizedBox(height: HermesSpacing.lg),

          // Join button
          _buildJoinButton(context, ref, codeState),
        ],
      ),
    );
  }

  Widget _buildCodeInput(
    BuildContext context,
    WidgetRef ref,
    SessionCodeState state,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Session Code', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: HermesSpacing.sm),

        Center(
          child: SessionCodeDisplay(
            code: state.value,
            hasError: state.shouldShowError,
            activeIndex: state.value.length < 6 ? state.value.length : null,
          ),
        ),

        const SizedBox(height: HermesSpacing.md),

        // Hidden text field for input
        TextField(
          decoration: const InputDecoration(
            hintText: 'ABC123',
            border: OutlineInputBorder(),
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(
            letterSpacing: 8,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
          maxLength: 6,
          textCapitalization: TextCapitalization.characters,
          onChanged: (value) {
            ref.read(sessionCodeInputProvider.notifier).updateCode(value);
          },
        ),
      ],
    );
  }

  Widget _buildErrorMessage(BuildContext context, String error) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(HermesSpacing.sm),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(HermesSpacing.sm),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            size: 16,
            color: theme.colorScheme.onErrorContainer,
          ),
          const SizedBox(width: HermesSpacing.xs),
          Text(
            error,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onErrorContainer,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJoinButton(
    BuildContext context,
    WidgetRef ref,
    SessionCodeState state,
  ) {
    return PrimaryButton(
      label: 'Join Session',
      icon: HermesIcons.people,
      isFullWidth: true,
      isLoading: isLoading,
      onPressed: state.isValid ? () => _handleJoin(ref) : null,
    );
  }

  void _handleJoin(WidgetRef ref) {
    final success = ref.read(sessionCodeInputProvider.notifier).submit();
    if (success) {
      onJoin?.call();
    }
  }
}
