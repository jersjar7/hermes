// lib/features/app/presentation/pages/home_page.dart

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes/features/app/presentation/widgets/hermes_app_bar.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';
import 'package:hermes/core/presentation/constants/hermes_icons.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: const HermesAppBar(),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(HermesSpacing.lg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App branding
              Icon(
                HermesIcons.translating,
                size: 80,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: HermesSpacing.md),
              Text(
                'Hermes',
                style: theme.textTheme.headlineLarge?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: HermesSpacing.sm),
              Text(
                'Real-time speech translation',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.outline,
                ),
              ),

              const SizedBox(height: HermesSpacing.xxl),

              // Role selection cards
              _buildRoleCard(
                context: context,
                title: 'Start Speaking Session',
                subtitle: 'Share your speech with translated audience',
                icon: HermesIcons.microphone,
                isPrimary: true,
                onTap: () => context.go('/speaker-setup'),
              ),

              const SizedBox(height: HermesSpacing.lg),

              _buildRoleCard(
                context: context,
                title: 'Join as Listener',
                subtitle: 'Listen to translated speech from a speaker',
                icon: HermesIcons.people,
                isPrimary: false,
                onTap: () => context.go('/audience-setup'),
              ),

              const SizedBox(height: HermesSpacing.xxl),

              // Helpful info
              Container(
                padding: const EdgeInsets.all(HermesSpacing.md),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.5,
                  ),
                  borderRadius: BorderRadius.circular(HermesSpacing.md),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 20,
                      color: theme.colorScheme.outline,
                    ),
                    const SizedBox(width: HermesSpacing.sm),
                    Expanded(
                      child: Text(
                        'Choose your role: speak to share your voice, or listen to receive translations.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      child: Card(
        elevation: isPrimary ? 4 : 2,
        shadowColor:
            isPrimary ? theme.colorScheme.primary.withValues(alpha: 0.3) : null,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(HermesSpacing.lg),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color:
                        isPrimary
                            ? theme.colorScheme.primary
                            : theme.colorScheme.primaryContainer,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 28,
                    color:
                        isPrimary
                            ? theme.colorScheme.onPrimary
                            : theme.colorScheme.primary,
                  ),
                ),

                const SizedBox(width: HermesSpacing.md),

                // Text content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: isPrimary ? theme.colorScheme.primary : null,
                        ),
                      ),
                      const SizedBox(height: HermesSpacing.xs),
                      Text(
                        subtitle,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.outline,
                        ),
                      ),
                    ],
                  ),
                ),

                // Arrow indicator
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: theme.colorScheme.outline,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
