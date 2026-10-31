import 'dart:math';
import 'dart:typed_data';

import 'package:cooker_whistle_counter/whistle_detector.dart';
import 'package:flutter_test/flutter_test.dart';

/// Builds little-endian PCM16 bytes: [tones] are (freqHz, durationMs, amplitude).
Uint8List pcm(List<(double, int, double)> tones) {
  final samples = <int>[];
  for (final (f, ms, a) in tones) {
    final n = WhistleDetector.sampleRate * ms ~/ 1000;
    for (int i = 0; i < n; i++) {
      samples.add((a * 32767 * sin(2 * pi * f * i / WhistleDetector.sampleRate))
          .round());
    }
  }
  final bd = ByteData(samples.length * 2);
  for (int i = 0; i < samples.length; i++) {
    bd.setInt16(i * 2, samples[i], Endian.little);
  }
  return bd.buffer.asUint8List();
}

void main() {
  test('counts two separate whistles', () {
    int count = 0;
    final d = WhistleDetector(onWhistle: () => count++);
    d.addBytes(pcm([
      (3000, 1500, 0.3), // whistle
      (0, 2500, 0), // quiet
      (3000, 1500, 0.3), // whistle
      (0, 2500, 0),
    ]));
    expect(count, 2);
  });

  test('ignores short clinks', () {
    int count = 0;
    final d = WhistleDetector(onWhistle: () => count++);
    d.addBytes(pcm([
      (3000, 100, 0.5),
      (0, 500, 0),
      (3000, 100, 0.5),
      (0, 500, 0),
    ]));
    expect(count, 0);
  });

  test('ignores low-frequency sound', () {
    int count = 0;
    final d = WhistleDetector(onWhistle: () => count++);
    d.addBytes(pcm([(300, 2000, 0.5)]));
    expect(count, 0);
  });

  test('handles odd-sized byte chunks', () {
    int count = 0;
    final d = WhistleDetector(onWhistle: () => count++);
    final bytes = pcm([(3000, 1500, 0.3), (0, 2000, 0)]);
    for (int i = 0; i < bytes.length; i += 333) {
      d.addBytes(bytes.sublist(i, min(i + 333, bytes.length)));
    }
    expect(count, 1);
  });
}
