import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';

/// The shared time source. Every orb, voice orb and border beam reads the
/// same clock, so any number of instances stay phase-locked (the equivalent
/// of the original's shared `performance.now()`).
///
/// Time is derived from the engine's frame timestamp, so all tickers firing
/// in one frame see the identical value, and it keeps advancing across pauses
/// — an orb resuming after being paused or off-route continues "in phase"
/// with the others rather than from where it stopped.
class ThinkingOrbClock {
  ThinkingOrbClock._();

  /// The process-wide clock.
  static final ThinkingOrbClock instance = ThinkingOrbClock._();

  Duration? _origin;
  double _seconds = 0;

  /// Seconds since the first frame any orb observed (0 before then).
  double get seconds => _seconds;

  /// Advances the clock to the frame being produced and returns the time.
  double sample() {
    final stamp = SchedulerBinding.instance.currentFrameTimeStamp;
    _origin ??= stamp;
    return _seconds = (stamp - _origin!).inMicroseconds / 1e6;
  }

  /// Resets the clock (tests).
  @visibleForTesting
  void reset() {
    _origin = null;
    _seconds = 0;
  }
}

/// A repaint [Listenable] carrying one widget's animation time.
///
/// It owns a single [Ticker] created from the host's [TickerProvider], so the
/// framework's `TickerMode` (inactive routes, offstage subtrees) mutes it for
/// free. Each tick only moves [t] and notifies the painter: no `setState`, no
/// widget rebuilds.
class OrbTimeline extends ChangeNotifier {
  /// Creates a timeline driven by [vsync].
  OrbTimeline(TickerProvider vsync) {
    _ticker = vsync.createTicker(_onTick);
  }

  late final Ticker _ticker;
  double _rate = 1;
  double _t = 0;
  bool _static = false;
  bool _initialized = false;

  /// Animation time in the preset's units: `clock seconds × rate`.
  double get t => _t;

  /// Whether the ticker is currently running.
  bool get isRunning => _ticker.isActive;

  /// Applies a new configuration.
  ///
  /// [rate] multiplies the shared clock. When [running] is false the timeline
  /// freezes on its current frame, or on [frozenAt] if given (reduced motion).
  void configure({required double rate, required bool running, double? frozenAt}) {
    _rate = rate;
    if (!_initialized) {
      _initialized = true;
      _t = ThinkingOrbClock.instance.seconds * rate;
    }
    if (frozenAt != null) {
      _static = true;
      _ticker.stop();
      _setT(frozenAt);
      return;
    }
    _static = false;
    if (running) {
      _setT(ThinkingOrbClock.instance.seconds * _rate);
      if (!_ticker.isActive) _ticker.start();
    } else {
      _ticker.stop();
    }
  }

  /// Forces listeners (painters) to repaint without changing time.
  void repaint() => notifyListeners();

  void _setT(double v) {
    if (v == _t) return;
    _t = v;
    notifyListeners();
  }

  void _onTick(Duration _) {
    if (_static) return;
    _t = ThinkingOrbClock.instance.sample() * _rate;
    notifyListeners();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }
}
