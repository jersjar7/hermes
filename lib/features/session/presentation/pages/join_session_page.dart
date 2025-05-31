// lib/features/session/presentation/pages/join_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/features/app/presentation/widgets/hermes_app_bar.dart';
import 'package:hermes/features/session/presentation/utils/language_helpers.dart';
import '../controllers/session_code_input_controller.dart';
import '../widgets/organisms/session_header.dart';
import '../widgets/organisms/session_join_form.dart';
import '../widgets/organisms/language_selector.dart';

/// Page for audience members to join existing sessions.
/// Handles session code input and target language selection.
class JoinSessionPage extends ConsumerStatefulWidget {
  const JoinSessionPage({super.key});

  @override
  ConsumerState<JoinSessionPage> createState() => _JoinSessionPageState();
}

class _JoinSessionPageState extends ConsumerState<JoinSessionPage> {
  LanguageOption? selectedLanguage;
  bool isJoining = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HermesAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Session status header
            const SessionHeader(showSessionCode: false),

            // Main content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Session join form
                    SessionJoinForm(
                      isLoading: isJoining,
                      onJoin: _handleJoinSession,
                    ),

                    const SizedBox(height: 24),

                    // Language selection
                    Text(
                      'Select Translation Language',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 16),

                    LanguageSelector(
                      selectedLanguageCode: selectedLanguage?.code,
                      maxHeight: 300,
                      onLanguageSelected: (language) {
                        setState(() => selectedLanguage = language);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleJoinSession() async {
    if (selectedLanguage == null) {
      _showLanguageRequiredSnackBar();
      return;
    }

    setState(() => isJoining = true);

    try {
      final sessionCode = ref.read(sessionCodeInputProvider).value;
      await ref
          .read(hermesControllerProvider.notifier)
          .joinSession(sessionCode);

      if (mounted) {
        context.go('/active-session');
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar(e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => isJoining = false);
      }
    }
  }

  void _showLanguageRequiredSnackBar() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Please select a language first')),
    );
  }

  void _showErrorSnackBar(String error) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('Failed to join session: $error')));
  }
}
