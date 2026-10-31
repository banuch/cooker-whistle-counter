import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:record/record.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'whistle_detector.dart';

void main() => runApp(const WhistleApp());

class WhistleApp extends StatelessWidget {
  const WhistleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whistle Counter',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepOrange,
        brightness: Brightness.dark,
      ),
      home: const CounterPage(),
    );
  }
}

class CounterPage extends StatefulWidget {
  const CounterPage({super.key});
  @override
  State<CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<CounterPage> {
  final _recorder = AudioRecorder();
  final _ringer = FlutterRingtonePlayer();
  final _det = WhistleDetector();
  final _level = ValueNotifier<double>(-90);
  StreamSubscription<Uint8List>? _sub;

  bool _listening = false;
  bool _alarm = false;
  int _count = 0;
  int _target = 3;
  double _threshold = -45;
  int _minMs = 400;
  final List<DateTime> _times = [];

  @override
  void initState() {
    super.initState();
    _det.onLevel = (db) => _level.value = db;
    _det.onWhistle = _onWhistle;
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    setState(() {
      _target = p.getInt('target') ?? 3;
      _threshold = p.getDouble('threshold') ?? -45;
      _minMs = p.getInt('minMs') ?? 400;
    });
    _det.thresholdDb = _threshold;
    _det.minWhistleMs = _minMs;
  }

  Future<void> _savePrefs() async {
    final p = await SharedPreferences.getInstance();
    await p.setInt('target', _target);
    await p.setDouble('threshold', _threshold);
    await p.setInt('minMs', _minMs);
  }

  Future<void> _start() async {
    if (!await _recorder.hasPermission()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission is needed')));
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
    setState(() => _listening = true);
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
    if (_count >= _target && !_alarm) _ringAlarm();
  }

  void _ringAlarm() {
    _alarm = true;
    _ringer.playAlarm(looping: true, asAlarm: true);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.local_fire_department, size: 40),
        title: Text('$_count whistles done!'),
        content: const Text('Turn off the stove.'),
        actions: [
          FilledButton(
            onPressed: () {
              _ringer.stop();
              _alarm = false;
              Navigator.pop(ctx);
              _stop();
            },
            child: const Text('Stop alarm'),
          ),
        ],
      ),
    );
  }

  void _reset() {
    _det.reset();
    setState(() {
      _count = 0;
      _times.clear();
    });
  }

  String _fmt(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:${t.second.toString().padLeft(2, '0')}';

  @override
  void dispose() {
    _sub?.cancel();
    _recorder.dispose();
    _ringer.stop();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Cooker Whistle Counter')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Big counter
          Center(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(
                    text: '$_count',
                    style: TextStyle(
                        fontSize: 110,
                        fontWeight: FontWeight.bold,
                        color: cs.primary)),
                TextSpan(
                    text: ' / $_target',
                    style: const TextStyle(fontSize: 40, color: Colors.grey)),
              ]),
            ),
          ),
          Center(
            child: Text(_listening ? 'Listening…' : 'Stopped',
                style: TextStyle(
                    color: _listening ? Colors.greenAccent : Colors.grey)),
          ),
          const SizedBox(height: 24),

          // Target stepper
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('Target whistles', style: TextStyle(fontSize: 16)),
              const SizedBox(width: 12),
              IconButton.filledTonal(
                onPressed: _target > 1
                    ? () {
                        setState(() => _target--);
                        _savePrefs();
                      }
                    : null,
                icon: const Icon(Icons.remove),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('$_target', style: const TextStyle(fontSize: 22)),
              ),
              IconButton.filledTonal(
                onPressed: () {
                  setState(() => _target++);
                  _savePrefs();
                },
                icon: const Icon(Icons.add),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Level meter with threshold marker
          ValueListenableBuilder<double>(
            valueListenable: _level,
            builder: (_, db, __) {
              double norm(double v) => ((v + 90) / 90).clamp(0.0, 1.0);
              final loud = db > _threshold;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Whistle band level: ${db.toStringAsFixed(0)} dB'),
                  const SizedBox(height: 6),
                  LayoutBuilder(builder: (_, c) {
                    return Stack(children: [
                      Container(
                          height: 22,
                          decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(6))),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 60),
                        height: 22,
                        width: c.maxWidth * norm(db),
                        decoration: BoxDecoration(
                            color: loud ? Colors.redAccent : Colors.green,
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      Positioned(
                        left: c.maxWidth * norm(_threshold) - 1.5,
                        child: Container(
                            width: 3, height: 22, color: Colors.white),
                      ),
                    ]);
                  }),
                ],
              );
            },
          ),
          const SizedBox(height: 12),

          // Threshold slider
          Text('Detection threshold: ${_threshold.toStringAsFixed(0)} dB'),
          Slider(
            min: -90,
            max: 0,
            divisions: 90,
            value: _threshold,
            onChanged: (v) {
              setState(() => _threshold = v);
              _det.thresholdDb = v;
            },
            onChangeEnd: (_) => _savePrefs(),
          ),
          const Text(
            'Tip: with normal kitchen noise the bar should stay green. '
            'Put the white line between that and the level during a whistle.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),

          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Advanced'),
            children: [
              Text('Minimum whistle length: $_minMs ms'),
              Slider(
                min: 150,
                max: 1500,
                divisions: 27,
                value: _minMs.toDouble(),
                onChanged: (v) {
                  setState(() => _minMs = v.round());
                  _det.minWhistleMs = _minMs;
                },
                onChangeEnd: (_) => _savePrefs(),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Controls
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(54)),
                onPressed: _listening ? _stop : _start,
                icon: Icon(_listening ? Icons.stop : Icons.mic),
                label: Text(_listening ? 'Stop' : 'Start listening'),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 54)),
              onPressed: _reset,
              icon: const Icon(Icons.restart_alt),
              label: const Text('Reset'),
            ),
          ]),
          const SizedBox(height: 20),

          // Whistle log
          if (_times.isNotEmpty) ...[
            const Text('Whistle log',
                style: TextStyle(fontWeight: FontWeight.bold)),
            for (int i = 0; i < _times.length; i++)
              ListTile(
                dense: true,
                leading: CircleAvatar(radius: 14, child: Text('${i + 1}')),
                title: Text(_fmt(_times[i])),
                trailing: i > 0
                    ? Text(
                        '+${_times[i].difference(_times[i - 1]).inSeconds}s')
                    : null,
              ),
          ],
        ],
      ),
    );
  }
}
