// lib/features/session/presentation/pages/active_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:provider/provider.dart';
import 'package:hermes/core/utils/extensions.dart';
import 'package:hermes/core/utils/logger.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/session/domain/usecases/end_session.dart';
import 'package:hermes/features/session/presentation/controllers/active_session_controller.dart';
import 'package:hermes/features/session/presentation/pages/session_summary_page.dart';
import 'package:hermes/features/translation/infrastructure/utils/permission_handler_util.dart';
import 'package:hermes/features/translation/presentation/controllers/speaker_controller.dart';
import 'package:hermes/features/translation/presentation/widgets/audio_level_indicator.dart';
import 'package:hermes/features/translation/presentation/widgets/live_transcript_view.dart';

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
  late PermissionHandlerUtil _permissionHandler;

  @override
  void initState() {
    super.initState();

    _controller = ActiveSessionController(
      speakerController: GetIt.instance<SpeakerController>(),
      endSession: GetIt.instance<EndSession>(),
      logger: GetIt.instance<Logger>(),
      session: widget.session,
    );

    _permissionHandler = PermissionHandlerUtil(GetIt.instance<Logger>());

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

  /// Handle main button (start/pause/resume) press
  void _handleMainButtonPress() async {
    if (_controller.isListening) {
      await _controller.togglePauseResume();
    } else {
      final success = await _controller.toggleListening();

      if (!success && _controller.errorMessage != null) {
        if (_controller.isPermissionError && mounted) {
          _permissionHandler.showPermissionSettingsDialog(
            context,
            onCancel: () {},
          );
        }
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
                  // Top status bar with language flag and listener count
                  _buildStatusBar(controller, language),

                  // Session details
                  _buildSessionDetails(controller),

                  // Microphone level indicator (always visible)
                  _buildMicrophoneIndicator(controller),

                  // Error message if any
                  if (controller.errorMessage != null)
                    _buildErrorMessage(controller),

                  // Live transcript (optional/toggleable)
                  if (controller.isListening && !controller.isInitializing)
                    Expanded(
                      child:
                          controller.showTranscription
                              ? _buildTranscriptView(controller, language)
                              : _buildMinimalView(controller),
                    ),

                  // Initial state or when not listening
                  if (!controller.isListening && !controller.isInitializing)
                    Expanded(child: _buildPreSpeakingView(controller)),

                  // Loading state
                  if (controller.isInitializing)
                    const Expanded(
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 16),
                            Text('Initializing microphone...'),
                          ],
                        ),
                      ),
                    ),

                  // Bottom action bar
                  _buildActionBar(controller),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusBar(
    ActiveSessionController controller,
    LanguageSelection language,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Speaker's language
          Row(
            children: [
              Text(language.flagEmoji, style: const TextStyle(fontSize: 20)),
              const SizedBox(width: 8),
              Text(
                language.englishName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ],
          ),

          // Listeners count
          Row(
            children: [
              const Icon(Icons.people, size: 20),
              const SizedBox(width: 6),
              Text(
                '${controller.listenerCount} ${controller.listenerCount == 1 ? 'listener' : 'listeners'}',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSessionDetails(ActiveSessionController controller) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Session name
          Text(
            'Session: ${controller.session.name}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),

          // Session code with copy option
          InkWell(
            onTap: _copySessionCode,
            child: Row(
              children: [
                Text(
                  'Code: ${controller.session.code}',
                  style: const TextStyle(fontSize: 14, fontFamily: 'monospace'),
                ),
                const SizedBox(width: 4),
                const Icon(Icons.copy, size: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicrophoneIndicator(ActiveSessionController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status indicator and toggle transcript visibility
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Status indicator (speaking/paused/not speaking)
              Row(
                children: [
                  Icon(
                    controller.isListening
                        ? controller.isPaused
                            ? Icons.pause
                            : Icons.mic
                        : Icons.mic_off,
                    color:
                        controller.isListening
                            ? controller.isPaused
                                ? Colors.amber
                                : Colors.green
                            : Colors.grey,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    controller.isListening
                        ? controller.isPaused
                            ? 'Paused'
                            : 'Speaking'
                        : 'Not Speaking',
                    style: TextStyle(
                      color:
                          controller.isListening
                              ? controller.isPaused
                                  ? Colors.amber
                                  : Colors.green
                              : Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),

              // Toggle transcript visibility
              if (controller.isListening)
                IconButton(
                  icon: Icon(
                    controller.showTranscription
                        ? Icons.visibility
                        : Icons.visibility_off,
                    size: 20,
                  ),
                  onPressed: controller.toggleTranscriptionVisibility,
                  tooltip:
                      controller.showTranscription
                          ? 'Hide transcription'
                          : 'Show transcription',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Audio level visualization
          AudioLevelIndicator(isListening: controller.isListening),
        ],
      ),
    );
  }

  Widget _buildErrorMessage(ActiveSessionController controller) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              controller.errorMessage ?? 'An error occurred',
              style: TextStyle(color: Colors.red.shade700),
            ),
          ),
          TextButton(
            onPressed: controller.retryAfterError,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(60, 36),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptView(
    ActiveSessionController controller,
    LanguageSelection language,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: LiveTranscriptView(
        sessionId: controller.session.id,
        sourceLanguage: language,
        targetLanguage: language,
        isSpeakerView: true,
      ),
    );
  }

  Widget _buildMinimalView(ActiveSessionController controller) {
    // Shown when transcript is hidden but speaking is active
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.mic, size: 48, color: Colors.green),
          const SizedBox(height: 16),
          const Text(
            'Actively Speaking',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Your speech is being transcribed and translated',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 8),
          Text(
            '${controller.listenerCount} ${controller.listenerCount == 1 ? 'listener' : 'listeners'} connected',
            style: TextStyle(color: Colors.grey.shade600),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.visibility),
            label: const Text('Show Live Transcript'),
            onPressed: controller.toggleTranscriptionVisibility,
          ),
        ],
      ),
    );
  }

  Widget _buildPreSpeakingView(ActiveSessionController controller) {
    // Initial view with instructions
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.record_voice_over, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            'Ready to Begin?',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Press the "Start Speaking" button below when you\'re ready to begin your session.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              'Your speech will be transcribed and translated in real-time for your audience.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(ActiveSessionController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(26),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Start/Pause/Resume button
          Expanded(
            child: ElevatedButton.icon(
              onPressed: _handleMainButtonPress,
              icon: Icon(_getButtonIcon(controller)),
              label: Text(_getButtonLabel(controller)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _getButtonColor(controller),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),

          const SizedBox(width: 16),

          // End session button
          ElevatedButton.icon(
            onPressed: controller.isEnding ? null : _handleEndSession,
            icon:
                controller.isEnding
                    ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                    : const Icon(Icons.close),
            label: const Text('End Session'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.grey.shade800,
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }

  // Helper methods for action bar button
  IconData _getButtonIcon(ActiveSessionController controller) {
    if (!controller.isListening) return Icons.mic;
    return controller.isPaused ? Icons.play_arrow : Icons.pause;
  }

  String _getButtonLabel(ActiveSessionController controller) {
    if (!controller.isListening) return 'Start Speaking';
    return controller.isPaused ? 'Resume Speaking' : 'Pause Speaking';
  }

  Color _getButtonColor(ActiveSessionController controller) {
    if (!controller.isListening) return context.theme.colorScheme.primary;
    return controller.isPaused ? Colors.amber : Colors.green;
  }
}
