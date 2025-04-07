// lib/features/audio/presentation/widgets/audio_player_widget.dart

import 'package:flutter/material.dart';

/// Widget for displaying and controlling audio playback
/// This is a placeholder that will be fully implemented in Phase 3
class AudioPlayerWidget extends StatefulWidget {
  /// Creates a new [AudioPlayerWidget]
  const AudioPlayerWidget({super.key});

  @override
  State<AudioPlayerWidget> createState() => _AudioPlayerWidgetState();
}

class _AudioPlayerWidgetState extends State<AudioPlayerWidget> {
  final bool _isPlaying = false;
  double _volume = 0.8;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            // Status indicator
            Row(
              children: [
                Icon(
                  _isPlaying ? Icons.hearing : Icons.hearing_disabled,
                  color: _isPlaying ? Colors.green : Colors.grey,
                ),
                const SizedBox(width: 8),
                Text(
                  _isPlaying
                      ? 'Listening to translation...'
                      : 'Waiting for the speaker...',
                  style: TextStyle(
                    color: _isPlaying ? Colors.green : Colors.grey,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Volume control
            Row(
              children: [
                const Icon(Icons.volume_down, size: 20),
                Expanded(
                  child: Slider(
                    value: _volume,
                    onChanged: (value) {
                      setState(() {
                        _volume = value;
                      });
                      // In Phase 3, this will control actual audio volume
                    },
                  ),
                ),
                const Icon(Icons.volume_up, size: 20),
              ],
            ),

            const SizedBox(height: 6),

            // Implementation note
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.amber.shade100,
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: Colors.amber),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Audio streaming will be implemented in Phase 3',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
