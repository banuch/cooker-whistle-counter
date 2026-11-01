import 'package:flutter/material.dart';

/// Alarm tones bundled in assets/ (synthesised, loop seamlessly).
enum AlarmSound {
  chime('Chime', 'Soft rising bells', 'alarm_chime.wav',
      Icons.notifications_active_rounded),
  bell('Kitchen bell', 'Classic timer ring', 'alarm_bell.wav',
      Icons.alarm_rounded),
  marimba('Marimba', 'Playful and bright', 'alarm_marimba.wav',
      Icons.music_note_rounded),
  digital('Digital beep', 'Short and sharp', 'alarm_digital.wav',
      Icons.watch_rounded);

  const AlarmSound(this.label, this.description, this.asset, this.icon);

  final String label;
  final String description;
  final String asset;
  final IconData icon;

  static AlarmSound byName(String? name) =>
      values.firstWhere((s) => s.name == name, orElse: () => chime);
}

/// Played on each counted whistle. Kept short and below 2 kHz so the
/// detector doesn't count it.
const dingAsset = 'ding.wav';
