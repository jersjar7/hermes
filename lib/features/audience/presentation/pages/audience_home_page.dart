// lib/features/audience/presentation/pages/audience_home_page.dart

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hermes/core/utils/extensions.dart';
import 'package:hermes/features/audio/presentation/widgets/audio_player_widget.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/session/domain/entities/session.dart';
import 'package:hermes/features/session/domain/repositories/session_repository.dart';
import 'package:hermes/features/session/infrastructure/services/auth_service.dart';
import 'package:hermes/features/translation/presentation/controllers/audience_controller.dart';
import 'package:hermes/features/translation/presentation/widgets/language_dropdown.dart';
import 'package:hermes/features/translation/presentation/widgets/live_transcript_view.dart';
import 'package:hermes/routes.dart';

/// Page for the audience view of an active session
class AudienceHomePage extends StatefulWidget {
  /// The active session
  final Session session;

  /// The selected language
  final LanguageSelection language;

  /// Creates a new [AudienceHomePage]
  const AudienceHomePage({
    super.key,
    required this.session,
    required this.language,
  });

  @override
  State<AudienceHomePage> createState() => _AudienceHomePageState();
}

class _AudienceHomePageState extends State<AudienceHomePage> {
  LanguageSelection _selectedLanguage;
  bool _isLeaving = false;
  String? _errorMessage;

  late Session _session;
  StreamSubscription? _sessionSubscription;

  final _authService = GetIt.instance<AuthService>();
  final _sessionRepository = GetIt.instance<SessionRepository>();

  _AudienceHomePageState() : _selectedLanguage = LanguageSelections.english;

  final AudienceController _audienceController =
      GetIt.instance<AudienceController>();

  @override
  void initState() {
    super.initState();
    _audienceController.setSessionAndLanguage(_session, _selectedLanguage);
    _session = widget.session;
    _selectedLanguage = widget.language;
    _setupSessionListener();
  }

  void _setupSessionListener() {
    // Subscribe to session updates
    _sessionSubscription = _sessionRepository.streamSession(_session.id).listen(
      (result) {
        result.fold(
          (failure) {
            if (mounted) {
              setState(() {
                _errorMessage = failure.message;
              });
            }
          },
          (session) {
            if (mounted) {
              setState(() {
                _session = session;

                // If session has ended, navigate back to home
                if (_session.status == SessionStatus.ended) {
                  _handleSessionEnded();
                }
              });
            }
          },
        );
      },
    );
  }

  Future<void> _handleSessionEnded() async {
    // Show dialog notifying the user that the session has ended
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: const Text('Session Ended'),
            content: const Text(
              'The speaker has ended this session. Thank you for joining!',
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();

                  // Navigate to home
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.home,
                    (route) => false,
                  );
                },
                child: const Text('OK'),
              ),
            ],
          ),
    );
  }

  Future<void> _handleLeaveSession() async {
    setState(() {
      _isLeaving = true;
      _errorMessage = null;
    });

    try {
      final userId = _authService.userId;

      if (userId != null) {
        await _sessionRepository.leaveSession(
          sessionId: _session.id,
          userId: userId,
        );
      }

      if (mounted) {
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.home,
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLeaving = false;
        });
      }
    }
  }

  Future<void> _handleLanguageChanged(LanguageSelection language) async {
    setState(() {
      _selectedLanguage = language;
    });

    // Update controller
    await _audienceController.changeLanguage(language);

    try {
      // Update user preference
      await _authService.updatePreferredLanguage(language.languageCode);
    } catch (e) {
      // Continue even if preference update fails
    }
  }

  @override
  void dispose() {
    _sessionSubscription?.cancel();
    _audienceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get speaker language
    final speakerLanguage =
        LanguageSelections.getByCode(_session.sourceLanguage) ??
        LanguageSelections.english;

    return Scaffold(
      appBar: AppBar(
        title: Text(_session.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            onPressed: _isLeaving ? null : _handleLeaveSession,
            tooltip: 'Leave session',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Source language indicator
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: context.theme.primaryColor.withOpacity(0.1),
              child: Row(
                children: [
                  const Icon(Icons.record_voice_over),
                  const SizedBox(width: 8),
                  Text(
                    'Speaker: ${speakerLanguage.flagEmoji} ${speakerLanguage.englishName}',
                    style: context.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),

            // Error message (if any)
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(8),
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(color: Colors.red.shade900),
                ),
              ),

            // Target language selector
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: LanguageDropdown(
                selectedLanguage: _selectedLanguage,
                onChanged: _handleLanguageChanged,
                label: 'Listening in:',
              ),
            ),

            // Audio player
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: AudioPlayerWidget(),
            ),

            const SizedBox(height: 16),

            // Live transcript
            Expanded(
              child: LiveTranscriptView(
                sessionId: _session.id,
                sourceLanguage: speakerLanguage,
                targetLanguage: _selectedLanguage,
                isSpeakerView: false,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
