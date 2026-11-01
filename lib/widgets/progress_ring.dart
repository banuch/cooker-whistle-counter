import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../brand.dart';

/// Circular whistle progress. While listening, ripples breathe with the mic
/// level; every new whistle gives the ring a little bounce.
class ProgressRing extends StatefulWidget {
  const ProgressRing({
    super.key,
    required this.count,
    required this.target,
    required this.listening,
    required this.level,
    required this.size,
  });

  final int count;
  final int target;
  final bool listening;
  final ValueListenable<double> level;
  final double size;

  @override
  State<ProgressRing> createState() => _ProgressRingState();
}

class _ProgressRingState extends State<ProgressRing>
    with TickerProviderStateMixin {
  late final _pulse = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
  late final _bump = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 450));

  @override
  void initState() {
    super.initState();
    if (widget.listening) _pulse.repeat();
  }

  @override
  void didUpdateWidget(ProgressRing old) {
    super.didUpdateWidget(old);
    if (widget.listening != old.listening) {
      widget.listening ? _pulse.repeat() : _pulse.stop();
    }
    if (widget.count > old.count) _bump.forward(from: 0);
  }

  @override
  void dispose() {
    _pulse.dispose();
    _bump.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = widget.size;
    final done = widget.count >= widget.target;
    final start = done ? const Color(0xFF4ADE80) : flameStart;
    final end = done ? const Color(0xFF16A34A) : flameEnd;

    return SizedBox.square(
      dimension: size,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: (widget.count / widget.target).clamp(0.0, 1.0)),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (context, progress, child) => AnimatedBuilder(
          animation: Listenable.merge([_pulse, _bump, widget.level]),
          builder: (context, child) {
            final bump = math.sin(math.pi * _bump.value);
            final intensity = ((widget.level.value + 75) / 60).clamp(0.2, 1.0);
            return Transform.scale(
              scale: 1 + 0.06 * bump,
              child: CustomPaint(
                painter: _RingPainter(
                  progress: progress,
                  pulse: _pulse.value,
                  intensity: widget.listening ? intensity : 0,
                  track: cs.surfaceContainerHighest,
                  start: start,
                  end: end,
                ),
                child: child,
              ),
            );
          },
          child: child,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 350),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: ScaleTransition(
                    scale: CurvedAnimation(
                        parent: anim, curve: Curves.easeOutBack),
                    child: child,
                  ),
                ),
                child: Text(
                  '${widget.count}',
                  key: ValueKey(widget.count),
                  style: TextStyle(
                    fontSize: size * 0.3,
                    height: 1,
                    fontWeight: FontWeight.w800,
                    color: cs.onSurface,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              SizedBox(height: size * 0.02),
              Text(
                'of ${widget.target} whistles',
                style: TextStyle(
                    fontSize: size * 0.055, color: cs.onSurfaceVariant),
              ),
              SizedBox(height: size * 0.05),
              _StatusPill(
                  listening: widget.listening, done: done, blink: _pulse),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill(
      {required this.listening, required this.done, required this.blink});

  final bool listening;
  final bool done;
  final Animation<double> blink;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (label, color) = done
        ? ('Done', const Color(0xFF22C55E))
        : listening
            ? ('Listening', const Color(0xFF22C55E))
            : ('Paused', cs.outline);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: blink,
            builder: (_, __) => Opacity(
              opacity: listening
                  ? 0.35 + 0.65 * math.sin(math.pi * blink.value).abs()
                  : 1,
              child: Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: TextStyle(
                  color: color, fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.pulse,
    required this.intensity,
    required this.track,
    required this.start,
    required this.end,
  });

  final double progress;
  final double pulse;
  final double intensity;
  final Color track;
  final Color start;
  final Color end;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final stroke = size.width * 0.065;
    final rippleRoom = size.width * 0.08;
    final r = size.width / 2 - stroke / 2 - rippleRoom;

    if (intensity > 0) {
      for (int k = 0; k < 3; k++) {
        final t = (pulse + k / 3) % 1.0;
        canvas.drawCircle(
          c,
          r + stroke / 2 + t * rippleRoom,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5 + 3 * (1 - t)
            ..color = start.withValues(alpha: (1 - t) * 0.5 * intensity),
        );
      }
    }

    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    final p = progress.clamp(0.0, 1.0);
    if (p <= 0) return;
    final rect = Rect.fromCircle(center: c, radius: r);
    final sweep = 2 * math.pi * p;
    final shader = SweepGradient(
      colors: [start, end],
      stops: [0, p],
      transform: const GradientRotation(-math.pi / 2),
    ).createShader(rect);

    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, stroke * 0.5)
        ..color = Colors.white.withValues(alpha: 0.5),
    );
    canvas.drawArc(
      rect,
      -math.pi / 2,
      sweep,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = shader,
    );

    final a = -math.pi / 2 + sweep;
    canvas.drawCircle(
      c + Offset(math.cos(a), math.sin(a)) * r,
      stroke * 0.28,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) => true;
}
