// lib/features/session/presentation/pages/speaker_setup_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/features/app/presentation/widgets/hermes_app_bar.dart';
import 'package:hermes/features/session/presentation/utils/language_helpers.dart';
import 'package:hermes/features/session/presentation/widgets/organisms/session_header.dart';
import 'package:hermes/features/session/presentation/widgets/organisms/language_selector.dart';
import 'package:hermes/features/session/presentation/widgets/organisms/session_lobby.dart';
import 'package:hermes/features/session/presentation/widgets/molecules/loading_overlay.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';

/// Speaker setup page handling language selection and session creation.
/// Flows: Language Selection → Session Lobby → Navigate to Speaker Active Page
class SpeakerSetupPage extends ConsumerStatefulWidget {
  const SpeakerSetupPage({super.key});

  @override
  ConsumerState<SpeakerSetupPage> createState() => _SpeakerSetupPageState();
}

class _SpeakerSetupPageState extends ConsumerState<SpeakerSetupPage> {
  LanguageOption? selectedLanguage;
  SpeakerSetupState currentState = SpeakerSetupState.languageSelection;
  String? sessionCode;

  // Loading states
  bool isCreatingSession = false;
  bool isGoingLive = false;
  String goLiveStatus = '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildContextAwareAppBar(),
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                // Dynamic header based on current state
                _buildStateHeader(),

                // Main content area
                Expanded(child: _buildCurrentStateContent()),
              ],
            ),

            // ✨ Using LoadingOverlay molecule instead of custom overlay
            if (isGoingLive) _buildGoLiveLoadingOverlay(),
          ],
        ),
      ),
    );
  }

  /// Builds context-aware app bar based on current state
  HermesAppBar _buildContextAwareAppBar() {
    switch (currentState) {
      case SpeakerSetupState.languageSelection:
        return const HermesAppBar(customTitle: 'Start New Session');

      case SpeakerSetupState.sessionLobby:
        return HermesAppBar(
          customTitle: 'Session Lobby',
          forceShowBack: true,
          customBackMessage:
              'Are you sure you want to cancel this session? The session code will be lost.',
          customBackTitle: 'Cancel Session',
        );
    }
  }

  Widget _buildStateHeader() {
    switch (currentState) {
      case SpeakerSetupState.languageSelection:
        return const SessionHeader(customTitle: 'Start New Session');
      case SpeakerSetupState.sessionLobby:
        return const SessionHeader(customTitle: 'Session Lobby');
    }
  }

  Widget _buildCurrentStateContent() {
    switch (currentState) {
      case SpeakerSetupState.languageSelection:
        return _buildLanguageSelection();
      case SpeakerSetupState.sessionLobby:
        return _buildSessionLobby();
    }
  }

  Widget _buildLanguageSelection() {
    return Padding(
      padding: const EdgeInsets.all(HermesSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Select Speaking Language',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: HermesSpacing.sm),
          Text(
            'Choose the language you\'ll be speaking in during the session',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.outline,
            ),
          ),
          const SizedBox(height: HermesSpacing.lg),
          Expanded(
            child: LanguageSelector(
              selectedLanguageCode: selectedLanguage?.code,
              onLanguageSelected: (language) {
                setState(() => selectedLanguage = language);
                _createSession();
              },
              maxHeight: double.infinity,
              showSearch: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionLobby() {
    if (sessionCode == null || selectedLanguage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SessionLobby(
      sessionCode: sessionCode!,
      selectedLanguage: selectedLanguage!,
      onGoLive: _goLive,
    );
  }

  /// ✨ Using LoadingOverlay molecule with ProgressStep atoms
  Widget _buildGoLiveLoadingOverlay() {
    final steps = _buildGoLiveSteps();

    return LoadingOverlay(
      title: 'Going Live',
      message: goLiveStatus,
      steps: steps,
    );
  }

  /// ✨ Using LoadingStep and ProgressStep atoms instead of custom implementation
  List<LoadingStep> _buildGoLiveSteps() {
    final allSteps = [
      'Checking microphone permissions',
      'Initializing speech recognition',
      'Connecting to session',
      'Starting live session',
    ];

    final currentStepIndex = _getCurrentStepIndex();

    return allSteps.asMap().entries.map((entry) {
      final index = entry.key;
      final stepText = entry.value;

      if (index < currentStepIndex) {
        return LoadingStep.completed(stepText);
      } else if (index == currentStepIndex) {
        return LoadingStep.current(stepText);
      } else {
        return LoadingStep.pending(stepText);
      }
    }).toList();
  }

  int _getCurrentStepIndex() {
    if (goLiveStatus.contains('microphone')) return 0;
    if (goLiveStatus.contains('speech') ||
        goLiveStatus.contains('recognition')) {
      return 1;
    }
    if (goLiveStatus.contains('connect')) return 2;
    if (goLiveStatus.contains('start')) return 3;
    return 0;
  }

  // State transition methods

  /// Creates session (moves from language selection to lobby)
  Future<void> _createSession() async {
    if (selectedLanguage == null) return;

    setState(() => isCreatingSession = true);

    try {
      setState(() => currentState = SpeakerSetupState.sessionLobby);

      final sessionService = getIt<ISessionService>();

      // Create session ID (no socket connection yet!)
      await sessionService.startSession(languageCode: selectedLanguage!.code);

      setState(() {
        sessionCode = sessionService.currentSession?.sessionId;
        isCreatingSession = false;
      });
    } catch (e) {
      print('Failed to create session: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to create session: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
        setState(() {
          currentState = SpeakerSetupState.languageSelection;
          isCreatingSession = false;
        });
      }
    }
  }

  /// Goes live (starts session and navigates to speaker active page)
  Future<void> _goLive() async {
    if (selectedLanguage == null) return;

    setState(() {
      isGoingLive = true;
      goLiveStatus = 'Preparing to go live...';
    });

    try {
      // Step 1: Microphone permissions
      setState(() => goLiveStatus = 'Checking microphone permissions...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 2: Speech recognition
      setState(() => goLiveStatus = 'Initializing speech recognition...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 3: Connecting to session
      setState(() => goLiveStatus = 'Connecting to session...');
      await Future.delayed(const Duration(milliseconds: 500));

      // Step 4: Start the actual session
      setState(() => goLiveStatus = 'Starting live session...');
      await Future.delayed(const Duration(milliseconds: 300));
      await ref
          .read(hermesControllerProvider.notifier)
          .startSession(selectedLanguage!.code);

      // Success! Navigate to speaker active page
      if (mounted) {
        context.go('/speaker-active');
      }
    } catch (e) {
      print('Failed to go live: $e');

      setState(() {
        isGoingLive = false;
        goLiveStatus = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to start session: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(HermesSpacing.sm),
            ),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
  }
}

/// Enum for speaker setup states (simplified - no active session)
enum SpeakerSetupState { languageSelection, sessionLobby }
