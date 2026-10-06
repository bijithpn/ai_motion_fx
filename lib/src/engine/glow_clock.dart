import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// A small frame clock for the glow effects.
///
/// It owns one [Ticker] (so `TickerMode` pauses it on hidden routes), keeps a
/// running [time] in seconds, and notifies its listeners once per frame. The
/// painters listen to it directly, which means a frame repaints without
/// rebuilding any widgets.
class GlowClock extends ChangeNotifier {
  /// Creates a clock. Call [setRunning] to start it.
  GlowClock(TickerProvider vsync, {this.onFrame}) {
    _ticker = vsync.createTicker(_tick);
  }

  /// Called every frame before listeners, with the scaled step in seconds.
  final void Function(double dt)? onFrame;

  late final Ticker _ticker;
  Duration _last = Duration.zero;

  /// Seconds of animation time that have elapsed (scaled by [speed]).
  double time = 0;

  /// Multiplier applied to every step.
  double speed = 1;

  /// Whether the underlying ticker is currently asked to run.
  bool get running => _ticker.isActive;

  /// Starts or stops the clock. Stopping keeps [time] where it is.
  void setRunning(bool run) {
    if (run == _ticker.isActive) return;
    if (run) {
      _last = Duration.zero;
      _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  void _tick(Duration elapsed) {
    // Cap the step so coming back from a stall doesn't make things jump.
    final dt = math.min((elapsed - _last).inMicroseconds / 1e6, 0.05) * speed;
    _last = elapsed;
    time += dt;
    onFrame?.call(dt);
    notifyListeners();
  }

  /// Repaints once without advancing time (used when a static frame changes).
  void poke() => notifyListeners();

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
