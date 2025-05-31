// lib/features/session/presentation/pages/host_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hermes/features/app/presentation/widgets/hermes_app_bar.dart';
import 'package:hermes/features/session/presentation/utils/language_helpers.dart';
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const HermesAppBar(),
      body: SafeArea(
        child: Column(
          children: [
            // Session status header
            const SessionHeader(showSessionCode: false),

            // Main content area
            Expanded(
              child:
                  selectedLanguage != null
                      ? _buildActiveSession()
                      : _buildLanguageSelection(),
            ),
          ],
        ),
      ),
    );
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
              },
            ),
          ),
        ],
      ),
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
}
