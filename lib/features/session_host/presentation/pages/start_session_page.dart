// lib/features/session_host/presentation/pages/start_session_page.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/permission/permission_service.dart';
import 'package:hermes/features/session_host/presentation/providers/host_session_controller.dart';
import 'package:hermes/features/session_host/presentation/widgets/connectivity_lost_banner.dart';
import 'package:hermes/features/session_host/presentation/widgets/permission_denied_dialog.dart';

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

  Future<void> _handleStart() async {
    final permissionService = getIt<IPermissionService>();
    final granted = await permissionService.requestMicrophonePermission();
    if (!granted) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => const PermissionDeniedDialog(),
      );
      return;
    }
    if (!mounted) return;
    final controller = ref.read(hostSessionControllerProvider.notifier);
    await controller.startSession(_selectedLanguage!);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<HostSessionState>(hostSessionControllerProvider, (prev, next) {
      if (prev?.sessionCode == null && next.sessionCode != null) {
        context.go('/host/code');
      }
    });

    final state = ref.watch(hostSessionControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Start Session')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const ConnectivityLostBanner(),
            const SizedBox(height: 16),
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
                      : (lang) => setState(() => _selectedLanguage = lang),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed:
                  state.isLoading || _selectedLanguage == null
                      ? null
                      : _handleStart,
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
