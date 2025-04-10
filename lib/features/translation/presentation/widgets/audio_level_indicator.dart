// lib/features/translation/presentation/widgets/audio_level_indicator.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

/// Widget that displays a real-time audio level indicator to show microphone activity
class AudioLevelIndicator extends StatefulWidget {
  /// Whether currently listening for audio
  final bool isListening;

  /// Height of the indicator
  final double height;

  /// Creates a new [AudioLevelIndicator]
  const AudioLevelIndicator({
    super.key,
    required this.isListening,
    this.height = 24.0,
  });

  @override
  State<AudioLevelIndicator> createState() => _AudioLevelIndicatorState();
}

class _AudioLevelIndicatorState extends State<AudioLevelIndicator> {
  double _level = 0.0;
  final _recorder = AudioRecorder();
  Timer? _levelTimer;
  bool _recorderInitialized = false;

  @override
  void initState() {
    super.initState();
    _startLevelMonitoring();
  }

  @override
  void didUpdateWidget(AudioLevelIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isListening != oldWidget.isListening) {
      if (widget.isListening) {
        _startLevelMonitoring();
      } else {
        _stopLevelMonitoring();
      }
    }
  }

  void _startLevelMonitoring() async {
    // Already monitoring, skip
    if (_levelTimer != null) return;

    // Check if we have microphone access
    final hasPermission = await Permission.microphone.isGranted;
    if (!hasPermission) {
      debugPrint('AudioLevelIndicator: No microphone permission');
      return;
    }

    // Start recorder in a very quiet mode just to monitor levels
    try {
      // Make sure we're not already recording
      if (await _recorder.isRecording()) {
        await _recorder.stop();
      }

      // ✅ Get a temporary path for the output
      final tempDir = await getTemporaryDirectory();
      final tempPath = '${tempDir.path}/audio_level_indicator.wav';

      // ✅ Start recording with a required path
      await _recorder.start(
        RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          bitRate: 16000,
          sampleRate: 8000,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
        ),
        path: tempPath,
      );

      _recorderInitialized = true;
      debugPrint('AudioLevelIndicator: Recorder started');

      // Start periodic level monitoring
      _levelTimer = Timer.periodic(const Duration(milliseconds: 200), (
        _,
      ) async {
        if (widget.isListening && mounted) {
          try {
            final amplitude = await _recorder.getAmplitude();

            // The amplitude.current usually ranges from 0 to about 0.3 for speech
            // We'll normalize it to a 0-1 scale with sensible thresholds for visual feedback
            final normalizedLevel = (amplitude.current / 0.3).clamp(0.0, 1.0);

            if (mounted) {
              setState(() {
                _level = normalizedLevel;
              });
            }
            debugPrint(
              'AudioLevelIndicator: Amplitude=${amplitude.current}, Normalized=$_level',
            );
          } catch (e) {
            debugPrint('AudioLevelIndicator: Error getting amplitude: $e');
          }
        }
      });
    } catch (e) {
      debugPrint('AudioLevelIndicator: Error starting level monitor: $e');
    }
  }

  void _stopLevelMonitoring() {
    debugPrint('AudioLevelIndicator: Stopping monitoring');
    _levelTimer?.cancel();
    _levelTimer = null;

    if (_recorderInitialized) {
      _recorder.stop().catchError((e) {
        debugPrint('AudioLevelIndicator: Error stopping recorder: $e');
        return null; // explicitly return a String? to match method signature
      });
    }
  }

  @override
  void dispose() {
    debugPrint('AudioLevelIndicator: Disposing');
    _stopLevelMonitoring();
    _recorder.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: widget.height,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(widget.height / 2),
      ),
      child: Stack(
        children: [
          // Level indicator bar
          FractionallySizedBox(
            widthFactor: _level,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.green.shade300,
                    Colors.green.shade500,
                    Colors.green.shade700,
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(widget.height / 2),
              ),
            ),
          ),

          // Text showing the level
          Center(
            child: Text(
              'Mic Level: ${(_level * 100).toStringAsFixed(0)}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: _level > 0.5 ? Colors.white : Colors.black87,
                shadows: [
                  Shadow(
                    offset: const Offset(1, 1),
                    blurRadius: 1.0,
                    color: Colors.black.withValues(alpha: 0.3),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
