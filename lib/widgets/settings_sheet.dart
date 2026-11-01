import 'package:flutter/material.dart';

import '../sounds.dart';

/// Bottom sheet for alarm tone, per-whistle ding and minimum whistle length.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({
    super.key,
    required this.sound,
    required this.ding,
    required this.minMs,
    required this.onSound,
    required this.onDing,
    required this.onMinMs,
    required this.onMinMsEnd,
  });

  final AlarmSound sound;
  final bool ding;
  final int minMs;
  final ValueChanged<AlarmSound> onSound;
  final ValueChanged<bool> onDing;
  final ValueChanged<int> onMinMs;
  final VoidCallback onMinMsEnd;

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  late AlarmSound _sound = widget.sound;
  late bool _ding = widget.ding;
  late int _minMs = widget.minMs;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final section = tt.labelLarge
        ?.copyWith(color: cs.primary, fontWeight: FontWeight.w700);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Settings',
              style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          Text('ALARM SOUND', style: section),
          const SizedBox(height: 4),
          Text('Tap to preview.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
          const SizedBox(height: 12),
          for (final s in AlarmSound.values)
            _SoundTile(
              sound: s,
              selected: s == _sound,
              onTap: () {
                setState(() => _sound = s);
                widget.onSound(s);
              },
            ),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Ding on every whistle'),
            subtitle: const Text('A soft chime each time one is counted'),
            value: _ding,
            onChanged: (v) {
              setState(() => _ding = v);
              widget.onDing(v);
            },
          ),
          const SizedBox(height: 12),
          Text('DETECTION', style: section),
          const SizedBox(height: 8),
          Row(children: [
            const Expanded(child: Text('Minimum whistle length')),
            Text('$_minMs ms',
                style: tt.labelLarge?.copyWith(
                    fontFeatures: const [FontFeature.tabularFigures()])),
          ]),
          Slider(
            min: 150,
            max: 1500,
            divisions: 27,
            value: _minMs.toDouble(),
            onChanged: (v) {
              setState(() => _minMs = v.round());
              widget.onMinMs(_minMs);
            },
            onChangeEnd: (_) => widget.onMinMsEnd(),
          ),
          Text('Raise this if short hisses or clinks are being counted.',
              style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _SoundTile extends StatelessWidget {
  const _SoundTile(
      {required this.sound, required this.selected, required this.onTap});

  final AlarmSound sound;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        decoration: BoxDecoration(
          color: selected
              ? cs.primaryContainer.withValues(alpha: 0.6)
              : cs.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
              color: selected ? cs.primary : Colors.transparent, width: 2),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: selected ? cs.primary : cs.surfaceContainerHighest,
                  shape: BoxShape.circle,
                ),
                child: Icon(sound.icon,
                    color: selected ? cs.onPrimary : cs.onSurfaceVariant),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(sound.label,
                        style: tt.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    Text(sound.description,
                        style: tt.bodySmall
                            ?.copyWith(color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) =>
                    ScaleTransition(scale: anim, child: child),
                child: Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.play_circle_outline_rounded,
                  key: ValueKey(selected),
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
