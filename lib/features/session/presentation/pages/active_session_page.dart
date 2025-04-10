// lib/features/session/presentation/pages/active_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/session/domain/usecases/end_session.dart';
import 'package:hermes/features/session/presentation/controllers/active_session_controller.dart';
import 'package:hermes/features/session/presentation/pages/session_summary_page.dart';
import 'package:hermes/features/session/presentation/widgets/pre_speaking_view.dart';
import 'package:hermes/features/session/presentation/widgets/session_action_bar.dart';
import 'package:hermes/features/session/presentation/widgets/session_status_bar.dart';
import 'package:hermes/features/session/presentation/widgets/speaking_view.dart';
import 'package:hermes/features/translation/presentation/controllers/speaker_controller.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

/// Page for active session for speaker
class ActiveSessionPage extends StatefulWidget {
  /// The active session
  final Session session;

  /// Creates a new [ActiveSessionPage]
  const ActiveSessionPage({super.key, required this.session});

  @override
  State<ActiveSessionPage> createState() => _ActiveSessionPageState();
}

class _ActiveSessionPageState extends State<ActiveSessionPage>
    with WidgetsBindingObserver {
  late ActiveSessionController _controller;

  @override
  void initState() {
    super.initState();

    _controller = ActiveSessionController(
      speakerController: GetIt.instance<SpeakerController>(),
      endSession: GetIt.instance<EndSession>(),
      logger: GetIt.instance<Logger>(),
      session: widget.session,
    );

    // Add as observer to handle app lifecycle changes
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // If returning to foreground, check permission again
    if (state == AppLifecycleState.resumed &&
        !_controller.hasCheckedPermission) {
      _controller.checkMicrophonePermission();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  /// Show permission settings dialog
  void _showPermissionSettingsDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Microphone Permission Required'),
            content: const Text(
              'Hermes needs microphone access to transcribe your speech. '
              'Please enable microphone permission in settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Not Now'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  openAppSettings();
                },
                child: const Text('Open Settings'),
              ),
            ],
          ),
    );
  }

  /// Handle main button (start/pause/resume) press
  void _handleMainButtonPress() async {
    if (_controller.isListening) {
      await _controller.togglePauseResume();
    } else {
      final success = await _controller.toggleListening();

      if (!success && _controller.errorMessage != null && mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_controller.errorMessage!)));
      }
    }
  }

  /// Handle end session
  void _handleEndSession() async {
    final success = await _controller.endSession();

    if (success && mounted) {
      // Calculate session duration
      final sessionDuration = _controller.getSessionDuration();

      // Navigate to summary page
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder:
              (context) => SessionSummaryPage(
                session: _controller.session,
                transcripts: _controller.transcripts,
                audienceCount: _controller.listenerCount,
                sessionDuration: sessionDuration,
              ),
        ),
      );
    } else if (!success && _controller.errorMessage != null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_controller.errorMessage!)));
    }
  }

  /// Copy session code to clipboard
  void _copySessionCode() {
    Clipboard.setData(ClipboardData(text: _controller.session.code));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session code copied to clipboard')),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Get language selection from session
    final language =
        LanguageSelections.getByCode(_controller.session.sourceLanguage) ??
        LanguageSelections.english;

    // Use ChangeNotifierProvider to rebuild only when controller state changes
    return ChangeNotifierProvider.value(
      value: _controller,
      child: Consumer<ActiveSessionController>(
        builder: (context, controller, child) {
          return Scaffold(
            appBar: AppBar(
              title: Text(controller.session.name),
              actions: [
                // Show session code in app bar for quick access
                if (controller.viewState == SessionViewState.speaking)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Text(
                        'Code: ${controller.session.code}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.copy),
                  onPressed: _copySessionCode,
                  tooltip: 'Copy session code',
                ),
              ],
            ),
            body: SafeArea(
              child: Column(
                children: [
                  // Top bar with consistent info
                  SessionStatusBar(
                    isListening: controller.isListening,
                    isPaused: controller.isPaused,
                    language: language,
                    listenerCount: controller.listenerCount,
                  ),

                  // Body content based on current state
                  Expanded(
                    child:
                        controller.viewState == SessionViewState.preSpeaking
                            ? PreSpeakingView(
                              sessionName: controller.session.name,
                              sessionCode: controller.session.code,
                              onCopyTap: _copySessionCode,
                            )
                            : SpeakingView(
                              sessionId: controller.session.id,
                              sessionName: controller.session.name,
                              sessionCode: controller.session.code,
                              language: language,
                              showTranscription: controller.showTranscription,
                              listenerCount: controller.listenerCount,
                              onToggleTranscriptionVisibility:
                                  controller.toggleTranscriptionVisibility,
                            ),
                  ),

                  // Error message (if any)
                  if (controller.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(8),
                      margin: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        controller.errorMessage!,
                        style: TextStyle(color: Colors.red.shade900),
                      ),
                    ),

                  // Bottom action bar
                  SessionActionBar(
                    isListening: controller.isListening,
                    isPaused: controller.isPaused,
                    isEnding: controller.isEnding,
                    onMainActionPressed: _handleMainButtonPress,
                    onEndSessionPressed: _handleEndSession,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
