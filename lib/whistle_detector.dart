import 'dart:math';
import 'dart:typed_data';

/// Detects pressure-cooker whistles from a raw PCM16 mono stream.
///
/// Measures average energy in the 2–4.5 kHz band (where the whistle hiss
/// lives) using a bank of Goertzel filters on Hann-windowed 512-sample frames.
/// A whistle is counted when the band stays above [thresholdDb] for at least
/// [minWhistleMs]; it can't be counted again until it has been quiet for
/// [quietGapMs].
class WhistleDetector {
  static const int sampleRate = 16000;
  static const int frameSize = 512; // 32 ms per frame
  static const double frameMs = frameSize * 1000 / sampleRate;

  double thresholdDb;
  int minWhistleMs;
  int quietGapMs;

  void Function()? onWhistle;
  void Function(double db)? onLevel;

  WhistleDetector({
    this.thresholdDb = -45,
    this.minWhistleMs = 400,
    this.quietGapMs = 1500,
    this.onWhistle,
    this.onLevel,
  });

  final List<double> _coeffs = [
    for (double f = 2000; f <= 4500; f += 125) 2 * cos(2 * pi * f / sampleRate)
  ];
  final Float64List _window = Float64List.fromList(List.generate(
      frameSize, (i) => 0.5 - 0.5 * cos(2 * pi * i / (frameSize - 1))));
  final Float64List _frame = Float64List(frameSize);

  int _fill = 0;
  int? _carry; // odd byte left over between chunks
  double _timeMs = 0;
  double _loudStart = -1;
  double _lastLoud = -1e9;
  bool _active = false;

  void reset() {
    _fill = 0;
    _carry = null;
    _timeMs = 0;
    _loudStart = -1;
    _lastLoud = -1e9;
    _active = false;
  }

  /// Feed raw little-endian PCM16 bytes from the recorder stream.
  void addBytes(Uint8List data) {
    int i = 0;
    if (_carry != null && data.isNotEmpty) {
      _push(_toInt16(_carry!, data[0]));
      _carry = null;
      i = 1;
    }
    for (; i + 1 < data.length; i += 2) {
      _push(_toInt16(data[i], data[i + 1]));
    }
    if (i < data.length) _carry = data[i];
  }

  int _toInt16(int lo, int hi) {
    final v = lo | (hi << 8);
    return v >= 32768 ? v - 65536 : v;
  }

  void _push(int sample) {
    _frame[_fill++] = sample / 32768.0;
    if (_fill == frameSize) {
      _fill = 0;
      _processFrame();
    }
  }

  void _processFrame() {
    double total = 0;
    for (final c in _coeffs) {
      double s1 = 0, s2 = 0;
      for (int n = 0; n < frameSize; n++) {
        final s = _frame[n] * _window[n] + c * s1 - s2;
        s2 = s1;
        s1 = s;
      }
      total += s1 * s1 + s2 * s2 - c * s1 * s2;
    }
    // Normalise to roughly 0..1 amplitude (Hann window gain = 0.5).
    final amp = sqrt(total / _coeffs.length) / (frameSize / 4);
    final db = 20 * log(max(amp, 1e-9)) / ln10;

    _timeMs += frameMs;
    onLevel?.call(db);

    if (db > thresholdDb) {
      if (_loudStart < 0) _loudStart = _timeMs;
      _lastLoud = _timeMs;
      if (!_active && _timeMs - _loudStart >= minWhistleMs) {
        _active = true;
        onWhistle?.call();
      }
    } else {
      // Short bangs/clinks: forget them quickly if they didn't qualify.
      if (!_active && _timeMs - _lastLoud > 200) _loudStart = -1;
      // A real whistle: wait for proper silence before re-arming.
      if (_active && _timeMs - _lastLoud > quietGapMs) {
        _active = false;
        _loudStart = -1;
      }
    }
  }
}
