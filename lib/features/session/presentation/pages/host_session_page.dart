// lib/features/session/presentation/pages/host_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes/core/hermes_engine/hermes_controller.dart';
import 'package:hermes/core/hermes_engine/state/hermes_status.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/session/session_service.dart';
import 'package:hermes/features/app/presentation/widgets/hermes_app_bar.dart';
import 'package:hermes/features/session/presentation/utils/language_helpers.dart';
import 'package:hermes/features/session/presentation/widgets/organisms/session_header.dart';
import 'package:hermes/features/session/presentation/widgets/organisms/language_selector.dart';
import 'package:hermes/features/session/presentation/widgets/organisms/session_lobby.dart';
import 'package:hermes/features/session/presentation/widgets/organisms/speaker_control_panel.dart';
import 'package:hermes/features/session/presentation/widgets/organisms/session_status_bar.dart';
import 'package:hermes/core/presentation/constants/spacing.dart';

/// Complete host session page implementing the three-state structure:
/// 1. Language Selection - Choose speaking language
/// 2. Session Lobby - Share session code, wait for audience, go live
/// 3. Active Session - Simplified speaking interface with transcript history
class HostSessionPage extends ConsumerStatefulWidget {
  const HostSessionPage({super.key});

  @override
  ConsumerState<HostSessionPage> createState() => _HostSessionPageState();
}

class _HostSessionPageState extends ConsumerState<HostSessionPage> {
  LanguageOption? selectedLanguage;
  SessionPageState currentState = SessionPageState.languageSelection;
  String? sessionCode;
  DateTime? sessionStartTime;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildContextAwareAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Dynamic header based on current state
            _buildStateHeader(),

            // Main content area
            Expanded(child: _buildCurrentStateContent()),

            // Session status bar (only during active session)
            if (currentState == SessionPageState.activeSession)
              _buildActiveSessionStatusBar(),
          ],
        ),
      ),
    );
  }

  /// Builds context-aware app bar based on current state
  HermesAppBar _buildContextAwareAppBar() {
    switch (currentState) {
      case SessionPageState.languageSelection:
        return const HermesAppBar(
          customTitle: 'Start New Session',
          // Simple back navigation to home
        );

      case SessionPageState.sessionLobby:
        return HermesAppBar(
          customTitle: 'Session Lobby',
          // Force show back button and override navigation
          forceShowBack: true,
          customBackMessage:
              'Are you sure you want to cancel this session? The session code will be lost.',
          customBackTitle: 'Cancel Session',
        );

      case SessionPageState.activeSession:
        return const HermesAppBar(
          customTitle: 'Live Session',
          // Smart session-aware navigation (handled automatically)
          customBackMessage:
              'Are you sure you want to end this session? All audience members will be disconnected.',
          customBackTitle: 'End Session',
        );
    }
  }

  Widget _buildStateHeader() {
    switch (currentState) {
      case SessionPageState.languageSelection:
        return const SessionHeader(customTitle: 'Start New Session');
      case SessionPageState.sessionLobby:
        return const SessionHeader(customTitle: 'Session Lobby');
      case SessionPageState.activeSession:
        return const SessionHeader(showMinimal: true);
    }
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

  Widget _buildActiveSession() {
    if (selectedLanguage == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Column(
      children: [
        // Speaker control panel (simplified for active sessions)
        SpeakerControlPanel(languageCode: selectedLanguage!.code),
        const SizedBox(height: HermesSpacing.sm),
        // Session controls
        _buildSessionControls(),
      ],
    );
  }

  Widget _buildActiveSessionStatusBar() {
    if (sessionCode == null || sessionStartTime == null) {
      return const SizedBox.shrink();
    }

    final sessionState = ref.watch(hermesControllerProvider);

    return sessionState.when(
      data:
          (state) => SessionStatusBar(
            sessionCode: sessionCode!,
            sessionDuration: DateTime.now().difference(sessionStartTime!),
            audienceCount: state.audienceCount,
            languageDistribution: state.languageDistribution,
            onSessionCodeTap: _copySessionCode,
          ),
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildSessionControls() {
    return Container(
      padding: const EdgeInsets.all(HermesSpacing.md),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: Border(
          top: BorderSide(
            color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          TextButton.icon(
            onPressed: _showEndSessionDialog,
            icon: const Icon(Icons.stop_rounded),
            label: const Text('End Session'),
          ),
          TextButton.icon(
            onPressed: _showSessionDetails,
            icon: const Icon(Icons.info_outline),
            label: const Text('Session Info'),
          ),
        ],
      ),
    );
  }

  // State transition methods
  Future<void> _createSession() async {
    if (selectedLanguage == null) return;

    try {
      setState(() => currentState = SessionPageState.sessionLobby);

      final sessionService = getIt<ISessionService>();
      await sessionService.startSession(languageCode: selectedLanguage!.code);

      setState(() {
        sessionCode = sessionService.currentSession?.sessionId;
      });
    } catch (e) {
      print('Failed to create session: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to create session: $e')));
        setState(() => currentState = SessionPageState.languageSelection);
      }
    }
  }

  Future<void> _goLive() async {
    if (selectedLanguage == null) return;

    try {
      // Start the actual speaking session
      await ref
          .read(hermesControllerProvider.notifier)
          .startSession(selectedLanguage!.code);

      setState(() {
        currentState = SessionPageState.activeSession;
        sessionStartTime = DateTime.now();
      });
    } catch (e) {
      print('Failed to go live: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to start session: $e')));
      }
    }
  }

  // Helper methods
  Future<void> _copySessionCode() async {
    if (sessionCode != null) {
      await Clipboard.setData(ClipboardData(text: sessionCode!));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Session code copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _showEndSessionDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('End Session'),
            content: const Text(
              'Are you sure you want to end this session? All audience members will be disconnected.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('End Session'),
              ),
            ],
          ),
    );

    if (confirmed == true && mounted) {
      await _endSession();
    }
  }

  Future<void> _endSession() async {
    try {
      await ref.read(hermesControllerProvider.notifier).stop();
      if (mounted) {
        context.go('/');
      }
    } catch (e) {
      print('Failed to end session: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to end session: $e')));
      }
    }
  }

  void _showSessionDetails() {
    final sessionState = ref.read(hermesControllerProvider);

    sessionState.whenData((state) {
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Session Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailRow('Session Code', sessionCode ?? 'Unknown'),
                  _buildDetailRow(
                    'Language',
                    selectedLanguage?.name ?? 'Unknown',
                  ),
                  _buildDetailRow('Status', _getStatusText(state.status)),
                  _buildDetailRow(
                    'Audience',
                    '${state.audienceCount} listeners',
                  ),
                  if (sessionStartTime != null)
                    _buildDetailRow(
                      'Duration',
                      _formatDuration(
                        DateTime.now().difference(sessionStartTime!),
                      ),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Close'),
                ),
              ],
            ),
      );
    });
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: HermesSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            child: Text(value, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  String _getStatusText(HermesStatus status) {
    switch (status) {
      case HermesStatus.idle:
        return 'Ready';
      case HermesStatus.listening:
        return 'Live';
      case HermesStatus.translating:
        return 'Processing';
      case HermesStatus.buffering:
        return 'Buffering';
      case HermesStatus.countdown:
        return 'Starting';
      case HermesStatus.speaking:
        return 'Playing';
      case HermesStatus.paused:
        return 'Paused';
      case HermesStatus.error:
        return 'Error';
    }
  }

  String _formatDuration(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes % 60;
    final seconds = duration.inSeconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m ${seconds}s';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    } else {
      return '${seconds}s';
    }
  }

  @override
  void dispose() {
    // Clean up if needed
    super.dispose();
  }
}

/// Enum representing the three states of the host session page
enum SessionPageState { languageSelection, sessionLobby, activeSession }
