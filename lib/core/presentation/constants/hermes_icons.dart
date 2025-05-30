// lib/core/presentation/constants/hermes_icons.dart

import 'package:flutter/material.dart';

/// Centralized icon definitions for the Hermes app.
/// Using Material Icons with semantic naming.
class HermesIcons {
  // Prevent instantiation
  HermesIcons._();

  // Session icons
  static const IconData microphone = Icons.mic_rounded;
  static const IconData microphoneOff = Icons.mic_off_rounded;
  static const IconData speaker = Icons.volume_up_rounded;
  static const IconData speakerOff = Icons.volume_off_rounded;
  static const IconData people = Icons.people_rounded;

  // Status icons
  static const IconData listening = Icons.hearing_rounded;
  static const IconData translating = Icons.translate_rounded;
  static const IconData speaking = Icons.record_voice_over_rounded;
  static const IconData buffering = Icons.hourglass_empty_rounded;
  static const IconData connected = Icons.wifi_rounded;
  static const IconData disconnected = Icons.wifi_off_rounded;

  // Action icons
  static const IconData play = Icons.play_arrow_rounded;
  static const IconData pause = Icons.pause_rounded;
  static const IconData stop = Icons.stop_rounded;
  static const IconData settings = Icons.settings_rounded;
  static const IconData share = Icons.share_rounded;
  static const IconData copy = Icons.copy_rounded;

  // Navigation icons
  static const IconData back = Icons.arrow_back_rounded;
  static const IconData close = Icons.close_rounded;
  static const IconData menu = Icons.menu_rounded;
}
