import 'dart:async';
import 'dart:math';
import 'package:sensors_plus/sensors_plus.dart';

/// Watches the accelerometer for a fall pattern: a brief near-weightless
/// moment (free-fall), immediately followed by a sharp impact, then a
/// period of stillness (suggesting the person is now down and not moving).
///
/// This runs only while the screen showing it is active — see the
/// honesty note in BUILD_INSTRUCTIONS.md about what a true always-on
/// background version would additionally require.
class FallDetectionService {
  StreamSubscription<AccelerometerEvent>? _sub;
  Timer? _stillnessTimer;

  // Tuned starting points — expect to adjust these after real testing.
  // Values are in m/s²; normal gravity at rest reads ~9.8.
  static const double _freeFallThreshold = 3.0; // near-weightless
  static const double _impactThreshold = 22.0; // sharp spike
  static const double _stillnessThreshold = 1.5; // low movement after impact
  static const Duration _stillnessWindow = Duration(seconds: 2);

  bool _inFreeFall = false;
  DateTime? _freeFallStart;

  void start({required void Function() onFallDetected}) {
    _sub = accelerometerEventsBridged().listen((event) {
      final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);

      if (!_inFreeFall && magnitude < _freeFallThreshold) {
        _inFreeFall = true;
        _freeFallStart = DateTime.now();
        return;
      }

      if (_inFreeFall && magnitude > _impactThreshold) {
        _inFreeFall = false;
        // Free-fall immediately followed by impact — now check for stillness.
        _watchForStillness(onFallDetected);
        return;
      }

      // Free-fall state that never resolves into an impact within ~1.5s
      // wasn't a fall (e.g. the phone was just set down gently).
      if (_inFreeFall && _freeFallStart != null && DateTime.now().difference(_freeFallStart!) > const Duration(milliseconds: 1500)) {
        _inFreeFall = false;
      }
    });
  }

  void _watchForStillness(void Function() onFallDetected) {
    final samples = <double>[];
    StreamSubscription<AccelerometerEvent>? stillnessSub;

    stillnessSub = accelerometerEventsBridged().listen((event) {
      final magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      samples.add((magnitude - 9.8).abs());
    });

    _stillnessTimer?.cancel();
    _stillnessTimer = Timer(_stillnessWindow, () {
      stillnessSub?.cancel();
      if (samples.isEmpty) return;
      final avgDeviation = samples.reduce((a, b) => a + b) / samples.length;
      if (avgDeviation < _stillnessThreshold) {
        onFallDetected();
      }
    });
  }

  /// Thin wrapper so the rest of this file doesn't repeat the same stream call.
  Stream<AccelerometerEvent> accelerometerEventsBridged() => accelerometerEventStream();

  void stop() {
    _sub?.cancel();
    _stillnessTimer?.cancel();
  }
}
