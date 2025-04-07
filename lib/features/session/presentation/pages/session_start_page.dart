// lib/features/session/presentation/pages/session_start_page.dart

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:hermes/core/utils/extensions.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/session/domain/entities/user.dart';
import 'package:hermes/features/session/domain/usecases/create_session.dart';
import 'package:hermes/features/session/infrastructure/services/auth_service.dart';
import 'package:hermes/routes.dart';

/// Page for starting a new session
class SessionStartPage extends StatefulWidget {
  /// Creates a new [SessionStartPage]
  const SessionStartPage({super.key});

  @override
  State<SessionStartPage> createState() => _SessionStartPageState();
}

class _SessionStartPageState extends State<SessionStartPage> {
  final _formKey = GlobalKey<FormState>();
  final _sessionNameController = TextEditingController();

  LanguageSelection _selectedLanguage = LanguageSelections.english;
  bool _isLoading = false;
  String? _errorMessage;

  final _createSession = GetIt.instance<CreateSession>();
  final _authService = GetIt.instance<AuthService>();

  @override
  void dispose() {
    _sessionNameController.dispose();
    super.dispose();
  }

  Future<void> _handleStartSession() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Ensure user is signed in
      final user =
          _authService.currentUser ?? await _authService.signInAnonymously();

      // Update user role to speaker
      await _authService.updateUserRole(UserRole.speaker);

      // Create the session
      final params = CreateSessionParams(
        name: _sessionNameController.text.trim(),
        speakerId: user.id,
        sourceLanguage: _selectedLanguage.languageCode,
      );

      final result = await _createSession(params);

      if (mounted) {
        result.fold(
          (failure) {
            setState(() {
              _errorMessage = failure.message;
              _isLoading = false;
            });
          },
          (session) {
            // Navigate to active session page
            Navigator.pushReplacementNamed(
              context,
              AppRoutes.activeSession,
              arguments: session,
            );
          },
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Start a Session')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),

                // Card with speaker instructions
                Card(
                  elevation: 2,
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'How it works:',
                          style: context.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '1. Create a session with a name and your speaking language',
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '2. Share your session code or QR code with your audience',
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          '3. Start speaking - your voice will be translated in real-time',
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Session name field
                TextFormField(
                  controller: _sessionNameController,
                  decoration: const InputDecoration(
                    labelText: 'Session Name',
                    hintText: 'Enter a name for your session',
                    prefixIcon: Icon(Icons.meeting_room),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a session name';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 24),

                // Language selection
                Text(
                  'Select your speaking language:',
                  style: context.textTheme.titleMedium,
                ),

                const SizedBox(height: 8),

                // Language dropdown
                DropdownButtonFormField<LanguageSelection>(
                  value: _selectedLanguage,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.language),
                  ),
                  items:
                      LanguageSelections.allLanguages
                          .map(
                            (language) => DropdownMenuItem(
                              value: language,
                              child: Row(
                                children: [
                                  Text(language.flagEmoji),
                                  const SizedBox(width: 8),
                                  Text(language.nativeName),
                                  const SizedBox(width: 8),
                                  Text(
                                    '(${language.englishName})',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedLanguage = value;
                      });
                    }
                  },
                ),

                const SizedBox(height: 32),

                // Error message (if any)
                if (_errorMessage != null)
                  Container(
                    padding: const EdgeInsets.all(8),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(color: Colors.red.shade900),
                    ),
                  ),

                // Start session button
                ElevatedButton(
                  onPressed: _isLoading ? null : _handleStartSession,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child:
                      _isLoading
                          ? const CircularProgressIndicator()
                          : const Text('Start Session'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
