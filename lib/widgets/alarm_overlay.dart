import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Full-screen pulsing alarm. [onStop] runs before the overlay closes.
Future<void> showAlarm(BuildContext context,
    {required int count, required VoidCallback onStop}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (ctx, _, __) => _AlarmView(
      count: count,
      onStop: () {
        onStop();
        Navigator.pop(ctx);
      },
    ),
    transitionBuilder: (_, anim, __, child) => FadeTransition(
      opacity: anim,
      child: ScaleTransition(
        scale: Tween(begin: 0.85, end: 1.0)
            .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutBack)),
        child: child,
      ),
    ),
  );
}

class _AlarmView extends StatefulWidget {
  const _AlarmView({required this.count, required this.onStop});

  final int count;
  final VoidCallback onStop;

  @override
  State<_AlarmView> createState() => _AlarmViewState();
}

class _AlarmViewState extends State<_AlarmView>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return PopScope(
      canPop: false,
      child: Material(
        type: MaterialType.transparency,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = Curves.easeInOut.transform(_c.value);
            return DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  radius: 1.1 + 0.25 * t,
                  colors: [
                    Color.lerp(
                        const Color(0xFFFF8A3D), const Color(0xFFFF4D4D), t)!,
                    const Color(0xFF7A1010),
                  ],
                ),
              ),
              child: child,
            );
          },
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox.square(
                      dimension: 200,
                      child: AnimatedBuilder(
                        animation: _c,
                        builder: (_, __) {
                          final t = _c.value;
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              for (final k in const [1.0, 0.75])
                                Container(
                                  width: 200 * k * (0.8 + 0.2 * t),
                                  height: 200 * k * (0.8 + 0.2 * t),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white
                                        .withValues(alpha: 0.08 + 0.06 * t),
                                  ),
                                ),
                              Transform.rotate(
                                angle: math.sin(t * math.pi * 4) * 0.12,
                                child: const Icon(
                                    Icons.local_fire_department_rounded,
                                    size: 96,
                                    color: Colors.white),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      '${widget.count} whistles done!',
                      textAlign: TextAlign.center,
                      style: tt.headlineMedium?.copyWith(
                          color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Text('Turn off the stove.',
                        style: tt.titleMedium?.copyWith(color: Colors.white70)),
                    const SizedBox(height: 48),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFFB91C1C),
                        minimumSize: const Size(240, 64),
                        shape: const StadiumBorder(),
                        textStyle: tt.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      onPressed: widget.onStop,
                      icon: const Icon(Icons.alarm_off_rounded),
                      label: const Text('Stop alarm'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
