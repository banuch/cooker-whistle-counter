import 'dart:async';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'brand.dart';
import 'sounds.dart';
import 'whistle_detector.dart';
import 'widgets/alarm_overlay.dart';
import 'widgets/level_meter.dart';
import 'widgets/progress_ring.dart';
import 'widgets/settings_sheet.dart';

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _dingPlayer = AudioPlayer();
  Timer? _buzz;
  final _det = WhistleDetector();
  final _level = ValueNotifier<double>(-90);
  StreamSubscription<Uint8List>? _sub;

  bool _listening = false;
  bool _alarm = false;
  int _count = 0;
  int _target = 3;
  double _threshold = -45;
  int _minMs = 400;
  AlarmSound _sound = AlarmSound.chime;
  bool _ding = true;
  DateTime? _startedAt;
  double _resetTurns = 0;
  final List<DateTime> _times = [];

  @override
  void initState() {
    super.initState();
    _det.onLevel = (db) => _level.value = db;
    _det.onWhistle = _onWhistle;
    _dingPlayer.setReleaseMode(ReleaseMode.stop);
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _target = p.getInt('target') ?? 3;
      _threshold = p.getDouble('threshold') ?? -45;
      _minMs = p.getInt('minMs') ?? 400;
      _sound = AlarmSound.byName(p.getString('sound'));
      _ding = p.getBool('ding') ?? true;
    });
    _det.thresholdDb = _threshold;
    _det.minWhistleMs = _minMs;
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('target', _target);
    await p.setDouble('threshold', _threshold);
    await p.setInt('minMs', _minMs);
    await p.setString('sound', _sound.name);
    await p.setBool('ding', _ding);
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Microphone permission is needed')));
      return;
    }
    final stream = await _recorder.startStream(const RecordConfig(
      encoder: AudioEncoder.pcm16bits,
      sampleRate: WhistleDetector.sampleRate,
      numChannels: 1,
      autoGain: false,
      echoCancel: false,
      noiseSuppress: false, // noise suppression would eat the whistle hiss
    ));
    _det.reset();
    _sub = stream.listen(_det.addBytes);
    await WakelockPlus.enable();
    HapticFeedback.mediumImpact();
    setState(() {
      _listening = true;
      _startedAt ??= DateTime.now();
    });
  }

  Future<void> _stop() async {
    await _sub?.cancel();
    _sub = null;
    await _recorder.stop();
    await WakelockPlus.disable();
    _level.value = -90;
    if (mounted) setState(() => _listening = false);
  }

  void _onWhistle() {
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    setState(() {
      _count++;
      _times.add(DateTime.now());
    });
    if (_count >= _target && !_alarm) {
      _ringAlarm();
    } else if (_ding) {
      _dingPlayer.play(AssetSource(dingAsset), volume: 0.8);
    }
  }

  void _ringAlarm() {
    _alarm = true;
    _stop(); // stop the mic so the alarm itself isn't counted as whistles
    _player.setReleaseMode(ReleaseMode.loop);
    _player.play(AssetSource(_sound.asset), volume: 1.0);
    _buzz = Timer.periodic(
        const Duration(milliseconds: 700), (_) => HapticFeedback.vibrate());
    showAlarm(context, count: _count, onStop: _stopAlarm);
  }

  void _stopAlarm() {
    _player.stop();
    _buzz?.cancel();
    _buzz = null;
    _alarm = false;
  }

  Future<void> _preview(AlarmSound s) async {
    await _player.stop();
    await _player.setReleaseMode(ReleaseMode.stop);
    await _player.play(AssetSource(s.asset));
  }

  void _reset() {
    _det.reset();
    HapticFeedback.selectionClick();
    setState(() {
      _count = 0;
      _times.clear();
      _startedAt = _listening ? DateTime.now() : null;
      _resetTurns -= 1;
    });
  }

  void _setTarget(int v) {
    HapticFeedback.selectionClick();
    setState(() => _target = v);
    _savePrefs();
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => SettingsSheet(
        sound: _sound,
        ding: _ding,
        minMs: _minMs,
        onSound: (s) {
          setState(() => _sound = s);
          _savePrefs();
          _preview(s);
        },
        onDing: (v) {
          setState(() => _ding = v);
          _savePrefs();
        },
        onMinMs: (v) {
          setState(() => _minMs = v);
          _det.minWhistleMs = v;
        },
        onMinMsEnd: _savePrefs,
      ),
    ).whenComplete(() {
      if (!_alarm) _player.stop();
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.dispose();
    _buzz?.cancel();
    _player.dispose();
    _dingPlayer.dispose();
    _level.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.soup_kitchen_rounded),
          SizedBox(width: 10),
          Text('Whistle Counter', style: TextStyle(fontWeight: FontWeight.w700)),
        ]),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color.alphaBlend(cs.primary.withValues(alpha: 0.14), cs.surface),
              cs.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth >= 720;
            final ring = (wide
                    ? math.min(c.maxHeight * 0.5, c.maxWidth * 0.36)
                    : math.min(c.maxWidth * 0.78, c.maxHeight * 0.44))
                .clamp(200.0, 380.0);

            final hero = [
              Center(
                child: ProgressRing(
                  count: _count,
                  target: _target,
                  listening: _listening,
                  level: _level,
                  size: ring,
                ),
              ),
              const SizedBox(height: 8),
              _Elapsed(
                  since: _startedAt,
                  last: _times.isEmpty ? null : _times.last),
              const SizedBox(height: 20),
              _TargetStepper(
                target: _target,
                onChanged: _setTarget,
              ),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                    child: _StartButton(
                        listening: _listening,
                        onPressed: _listening ? _stop : _start)),
                const SizedBox(width: 12),
                IconButton.filledTonal(
                  tooltip: 'Reset count',
                  style: IconButton.styleFrom(fixedSize: const Size(64, 64)),
                  onPressed: _reset,
                  icon: AnimatedRotation(
                    turns: _resetTurns,
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutBack,
                    child: const Icon(Icons.restart_alt_rounded),
                  ),
                ),
              ]),
            ];

            final details = [
              LevelMeter(
                level: _level,
                threshold: _threshold,
                onChanged: (v) {
                  setState(() => _threshold = v);
                  _det.thresholdDb = v;
                },
                onChangeEnd: _savePrefs,
              ),
              const SizedBox(height: 12),
              _WhistleLog(times: _times),
            ];

            const pad = EdgeInsets.fromLTRB(20, kToolbarHeight + 8, 20, 24);
            return Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1100),
                child: wide
                    ? Row(children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: pad,
                            child: Column(children: hero),
                          ),
                        ),
                        Expanded(
                          child: ListView(padding: pad, children: details),
                        ),
                      ])
                    : ListView(
                        padding: pad,
                        children: [
                          ...hero,
                          const SizedBox(height: 20),
                          ...details,
                        ],
                      ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

String _clock(Duration d) {
  final h = d.inHours, m = d.inMinutes % 60, s = d.inSeconds % 60;
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$ss' : '$m:$ss';
}

/// "Cooking 12:34 · last whistle 1:05 ago", ticking every second.
class _Elapsed extends StatefulWidget {
  const _Elapsed({required this.since, required this.last});

  final DateTime? since;
  final DateTime? last;

  @override
  State<_Elapsed> createState() => _ElapsedState();
}

class _ElapsedState extends State<_Elapsed> {
  late final Timer _tick =
      Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void dispose() {
    _tick.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final since = widget.since, last = widget.last;
    final text = since == null
        ? 'Tap start when the cooker goes on'
        : [
            'Cooking ${_clock(now.difference(since))}',
            if (last != null) 'last whistle ${_clock(now.difference(last))} ago',
          ].join('  ·  ');
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        color: cs.onSurfaceVariant,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _TargetStepper extends StatelessWidget {
  const _TargetStepper({required this.target, required this.onChanged});

  final int target;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
        child: Row(children: [
          Icon(Icons.flag_rounded, color: cs.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Target',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
          IconButton.filledTonal(
            onPressed: target > 1 ? () => onChanged(target - 1) : null,
            icon: const Icon(Icons.remove_rounded),
          ),
          SizedBox(
            width: 52,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: ScaleTransition(scale: anim, child: child),
              ),
              child: Text(
                '$target',
                key: ValueKey(target),
                textAlign: TextAlign.center,
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
            ),
          ),
          IconButton.filledTonal(
            onPressed: target < 30 ? () => onChanged(target + 1) : null,
            icon: const Icon(Icons.add_rounded),
          ),
        ]),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.listening, required this.onPressed});

  final bool listening;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    const fg = Colors.white;
    final colors = listening
        ? const [Color(0xFFE53935), Color(0xFFB71C1C)]
        : [flameStart, flameEnd];
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(colors: colors),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(32),
          onTap: onPressed,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              transitionBuilder: (child, anim) => FadeTransition(
                opacity: anim,
                child: SlideTransition(
                  position: Tween(
                          begin: const Offset(0, 0.4), end: Offset.zero)
                      .animate(anim),
                  child: child,
                ),
              ),
              child: Row(
                key: ValueKey(listening),
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(listening ? Icons.stop_rounded : Icons.mic_rounded,
                      color: fg),
                  const SizedBox(width: 10),
                  Text(
                    listening ? 'Stop listening' : 'Start listening',
                    style: TextStyle(
                        color: fg, fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WhistleLog extends StatelessWidget {
  const _WhistleLog({required this.times});

  final List<DateTime> times;

  static String _time(DateTime t) => [t.hour, t.minute, t.second]
      .map((v) => v.toString().padLeft(2, '0'))
      .join(':');

  static String _gap(Duration d) => d.inMinutes > 0
      ? '+${d.inMinutes}m ${(d.inSeconds % 60).toString().padLeft(2, '0')}s'
      : '+${d.inSeconds}s';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Card(
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(Icons.history_rounded, color: cs.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text('Whistle log',
                      style: tt.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600)),
                ),
              ]),
              const SizedBox(height: 8),
              if (times.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text('Whistles will appear here as they are counted.',
                      style:
                          tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant)),
                ),
              for (int i = times.length - 1; i >= 0; i--)
                _LogEntry(
                  key: ValueKey(times[i]),
                  index: i + 1,
                  time: _time(times[i]),
                  gap: i > 0 ? _gap(times[i].difference(times[i - 1])) : null,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogEntry extends StatelessWidget {
  const _LogEntry(
      {super.key, required this.index, required this.time, this.gap});

  final int index;
  final String time;
  final String? gap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    const tabular = [FontFeature.tabularFigures()];
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(-24 * (1 - t), 0), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [
          Container(
            width: 32,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: flame,
              shape: BoxShape.circle,
            ),
            child: Text('$index',
                style: const TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(time,
                style: const TextStyle(fontSize: 16, fontFeatures: tabular)),
          ),
          if (gap != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: cs.secondaryContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(gap!,
                  style: TextStyle(
                      color: cs.onSecondaryContainer,
                      fontWeight: FontWeight.w600,
                      fontFeatures: tabular)),
            ),
        ]),
      ),
    );
  }
}
