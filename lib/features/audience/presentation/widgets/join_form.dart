// lib/features/audience/presentation/widgets/join_form.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/utils/extensions.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';
import 'package:hermes/features/translation/presentation/widgets/language_dropdown.dart';

/// Form for joining a session with a code
class JoinForm extends StatefulWidget {
  /// Text controller for the code input
  final TextEditingController controller;

  /// Currently selected language
  final LanguageSelection selectedLanguage;

  /// Callback when language is changed
  final ValueChanged<LanguageSelection> onLanguageChanged;

  /// Callback when form is submitted
  final ValueChanged<String> onSubmit;

  /// Creates a new [JoinForm]
  const JoinForm({
    super.key,
    required this.controller,
    required this.selectedLanguage,
    required this.onLanguageChanged,
    required this.onSubmit,
  });

  @override
  State<JoinForm> createState() => _JoinFormState();
}

class _JoinFormState extends State<JoinForm> {
  final _formKey = GlobalKey<FormState>();

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      widget.onSubmit(widget.controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info card
          Card(
            elevation: 1,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How to join a session:',
                    style: context.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Enter the session code provided by the speaker or scan the QR code they shared.',
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Select your preferred language to hear the translation.',
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Session code input
          TextFormField(
            controller: widget.controller,
            decoration: const InputDecoration(
              labelText: 'Session Code',
              hintText: 'Enter the code (e.g., happy-tiger)',
              prefixIcon: Icon(Icons.tag),
            ),
            textInputAction: TextInputAction.go,
            onFieldSubmitted: (_) => _handleSubmit(),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Please enter a session code';
              }
              return null;
            },
          ),

          const SizedBox(height: 24),

          // Language selection
          LanguageDropdown(
            selectedLanguage: widget.selectedLanguage,
            onChanged: widget.onLanguageChanged,
            label: 'Select your preferred language:',
          ),

          const SizedBox(height: 32),

          // Join button
          ElevatedButton(
            onPressed: _handleSubmit,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: const Text('Join Session'),
          ),
        ],
      ),
    );
  }
}
