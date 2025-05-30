// lib/features/session_host/presentation/pages/start_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hermes/features/session_host/presentation/providers/host_session_controller.dart';

/// Page where the speaker selects a language and starts a new session.
class StartSessionPage extends ConsumerStatefulWidget {
  const StartSessionPage({super.key});

  @override
  ConsumerState<StartSessionPage> createState() => _StartSessionPageState();
}

class _StartSessionPageState extends ConsumerState<StartSessionPage> {
  // Supported languages map: display name → code
  final Map<String, String> _languages = {
    'English': 'en',
    'Spanish': 'es',
    'French': 'fr',
    'German': 'de',
    'Chinese': 'zh',
  };

  String? _selectedLanguage;

  @override
  void initState() {
    super.initState();
    _selectedLanguage = _languages.values.first;
  }

  @override
  Widget build(BuildContext context) {
    // Listen for the sessionCode being set, then navigate
    ref.listen<HostSessionState>(hostSessionControllerProvider, (
      previous,
      next,
    ) {
      if (previous?.sessionCode == null && next.sessionCode != null) {
        context.go('/host/code');
      }
    });

    final state = ref.watch(hostSessionControllerProvider);
    final controller = ref.read(hostSessionControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text('Start Session')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Select language:'),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              value: _selectedLanguage,
              decoration: const InputDecoration(border: OutlineInputBorder()),
              items:
                  _languages.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.value,
                          child: Text(e.key),
                        ),
                      )
                      .toList(),
              onChanged:
                  state.isLoading
                      ? null
                      : (lang) => setState(() {
                        _selectedLanguage = lang;
                      }),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  state.isLoading || _selectedLanguage == null
                      ? null
                      : () async {
                        await controller.startSession(_selectedLanguage!);
                      },
              child:
                  state.isLoading
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Text('Start Session'),
            ),
            if (state.errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                state.errorMessage!,
                style: const TextStyle(color: Colors.red),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
