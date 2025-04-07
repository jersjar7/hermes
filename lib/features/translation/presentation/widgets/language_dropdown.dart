// lib/features/translation/presentation/widgets/language_dropdown.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/utils/extensions.dart';
import 'package:hermes/features/session/domain/entities/language_selection.dart';

/// Dropdown widget for selecting a language
class LanguageDropdown extends StatelessWidget {
  /// Currently selected language
  final LanguageSelection selectedLanguage;

  /// Callback when language is changed
  final ValueChanged<LanguageSelection> onChanged;

  /// Label text for the dropdown
  final String label;

  /// Whether the dropdown is disabled
  final bool disabled;

  /// Creates a new [LanguageDropdown]
  const LanguageDropdown({
    super.key,
    required this.selectedLanguage,
    required this.onChanged,
    this.label = 'Select Language:',
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: context.textTheme.titleMedium),

        const SizedBox(height: 8),

        DropdownButtonFormField<LanguageSelection>(
          value: selectedLanguage,
          decoration: const InputDecoration(prefixIcon: Icon(Icons.language)),
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
          onChanged: disabled ? null : onChanged,
        ),
      ],
    );
  }
}
