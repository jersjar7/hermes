// lib/features/session_host/presentation/widgets/connectivity_lost_banner.dart

import 'package:flutter/material.dart';
import 'package:hermes/core/service_locator.dart';
import 'package:hermes/core/services/connectivity/connectivity_service.dart';

/// A sticky banner that appears whenever the device goes offline.
class ConnectivityLostBanner extends StatelessWidget {
  const ConnectivityLostBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final connectivityService = getIt<IConnectivityService>();

    return StreamBuilder<bool>(
      stream: connectivityService.onStatusChange,
      initialData: connectivityService.isOnline,
      builder: (context, snapshot) {
        final isOnline = snapshot.data ?? true;
        if (!isOnline) {
          return Container(
            width: double.infinity,
            color: Colors.redAccent,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: Row(
              children: const [
                Icon(Icons.cloud_off, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'No internet connection',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}
