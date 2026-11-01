import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../brand.dart';

/// Live whistle-band level with a draggable threshold marker.
class LevelMeter extends StatelessWidget {
  const LevelMeter({
    super.key,
    required this.level,
    required this.threshold,
    required this.onChanged,
    required this.onChangeEnd,
  });

  final ValueListenable<double> level;
  final double threshold;
  final ValueChanged<double> onChanged;
  final VoidCallback onChangeEnd;

  static const double _min = -90, _max = 0;
  static double _norm(double v) => ((v - _min) / (_max - _min)).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    const tabular = [FontFeature.tabularFigures()];

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.graphic_eq_rounded, color: cs.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text('Whistle detection',
                    style: tt.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600)),
              ),
              ValueListenableBuilder<double>(
                valueListenable: level,
                builder: (_, db, __) => Text('${db.toStringAsFixed(0)} dB',
                    style: tt.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant, fontFeatures: tabular)),
              ),
            ]),
            const SizedBox(height: 14),
            LayoutBuilder(builder: (context, c) {
              final w = c.maxWidth;
              void set(double dx) =>
                  onChanged((_min + (dx / w).clamp(0.0, 1.0) * (_max - _min))
                      .roundToDouble());
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => set(d.localPosition.dx),
                onTapUp: (_) => onChangeEnd(),
                onHorizontalDragUpdate: (d) => set(d.localPosition.dx),
                onHorizontalDragEnd: (_) => onChangeEnd(),
                child: SizedBox(
                  height: 44,
                  child: ValueListenableBuilder<double>(
                    valueListenable: level,
                    builder: (_, db, __) {
                      final loud = db > threshold;
                      return Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.centerLeft,
                        children: [
                          Container(
                            height: 14,
                            decoration: BoxDecoration(
                              color: cs.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(7),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 80),
                            height: 14,
                            width: w * _norm(db),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(7),
                              gradient: LinearGradient(
                                colors: loud
                                    ? const [flameStart, flameEnd]
                                    : const [
                                        Color(0xFF22C55E),
                                        Color(0xFF86EFAC)
                                      ],
                              ),
                              boxShadow: loud
                                  ? [
                                      BoxShadow(
                                          color: flameEnd.withValues(alpha: 0.5),
                                          blurRadius: 12)
                                    ]
                                  : null,
                            ),
                          ),
                          AnimatedPositioned(
                            duration: const Duration(milliseconds: 90),
                            left: w * _norm(threshold) - 12,
                            top: 0,
                            bottom: 0,
                            width: 24,
                            child: Center(
                              child: Container(
                                width: 6,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: cs.onSurface,
                                  borderRadius: BorderRadius.circular(3),
                                  boxShadow: const [
                                    BoxShadow(
                                        color: Colors.black38, blurRadius: 6)
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              );
            }),
            Row(children: [
              Text('More sensitive',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
              const Spacer(),
              Text('Trigger ${threshold.toStringAsFixed(0)} dB',
                  style: tt.labelSmall?.copyWith(
                      color: cs.onSurfaceVariant, fontFeatures: tabular)),
              const Spacer(),
              Text('Less sensitive',
                  style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
            ]),
            const SizedBox(height: 10),
            ValueListenableBuilder<double>(
              valueListenable: level,
              builder: (_, db, __) {
                final loud = db > threshold;
                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    loud
                        ? 'Hearing a whistle…'
                        : 'Drag the marker just above normal kitchen noise.',
                    key: ValueKey(loud),
                    style: tt.bodySmall?.copyWith(
                      color: loud ? flameEnd : cs.onSurfaceVariant,
                      fontWeight: loud ? FontWeight.w600 : null,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
