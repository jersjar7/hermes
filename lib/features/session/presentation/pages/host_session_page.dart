// lib/features/session/presentation/pages/host_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/features/app/presentation/widgets/hermes_app_bar.dart';
import 'package:hermes/features/session/presentation/utils/language_helpers.dart';
import 'package:hermes/features/session/presentation/widgets/organisms/session_lobby.dart';
import '../widgets/organisms/session_header.dart';
import '../widgets/organisms/language_selector.dart';
import '../widgets/organisms/speaker_control_panel.dart';
import '../widgets/organisms/translation_feed.dart';

/// Page for speakers to select language and start hosting sessions.
/// Provides language selection and speaker controls in a clean layout.
class HostSessionPage extends ConsumerStatefulWidget {
  const HostSessionPage({super.key});

  @override
  ConsumerState<HostSessionPage> createState() => _HostSessionPageState();
}

class _HostSessionPageState extends ConsumerState<HostSessionPage> {
  LanguageOption? selectedLanguage;
  SessionPageState currentState = SessionPageState.languageSelection;
  String? sessionCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HermesAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Session status header
            SessionHeader(
              sessionCode: sessionCode,
              showSessionCode:
                  currentState != SessionPageState.languageSelection,
            ),

            // Main content area
            Expanded(child: _buildCurrentStateContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStateContent() {
    switch (currentState) {
      case SessionPageState.languageSelection:
        return _buildLanguageSelection();
      case SessionPageState.sessionLobby:
        return _buildSessionLobby();
      case SessionPageState.activeSession:
        return _buildActiveSession();
    }
  }

  Widget _buildLanguageSelection() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Speaking Language',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Expanded(
            child: LanguageSelector(
              selectedLanguageCode: selectedLanguage?.code,
              onLanguageSelected: (language) {
                setState(() => selectedLanguage = language);
                _createSession();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionLobby() {
    return SessionLobby(
      sessionCode: sessionCode!,
      selectedLanguage: selectedLanguage!,
      onGoLive: () {
        setState(() => currentState = SessionPageState.activeSession);
      },
    );
  }

  Widget _buildActiveSession() {
    return Column(
      children: [
        // Speaker controls
        SpeakerControlPanel(languageCode: selectedLanguage!.code),

        // Translation feed
        const Expanded(child: TranslationFeed()),
      ],
    );
  }

  Future<void> _createSession() async {
    try {
      // Create session without starting it
      final sessionService = getIt<ISessionService>();
      await sessionService.startSession(languageCode: selectedLanguage!.code);

      setState(() {
        sessionCode = sessionService.currentSession?.sessionId;
        currentState = SessionPageState.sessionLobby;
      });
    } catch (e) {
      print('Failed to create session: $e');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to create session: $e')));
    }
  }
}

enum SessionPageState { languageSelection, sessionLobby, activeSession }
