import 'dart:math' as math;

import '../engine/orb_renderer.dart';
import '../engine/particle_system.dart';
import '../engine/projection.dart';
import '../models/thinking_orb_config.dart';
import '../models/thinking_orb_state.dart';

/// Geometry + smoothed dynamics for the voice orb.
///
/// Built from the `listening` wave lattice (same rings, projection, depth
/// shading and tuned dot sizes) with three additions: a smoothed *energy*
/// that scales the wave amplitude and tempo, a syllable envelope while
/// speaking, and the `searching` scan meridian blended in while processing.
/// Energy and scan weight ease toward their targets, so state and
/// [intensity] changes glide instead of snapping.
class VoiceFrameSource extends OrbFrameSource {
  /// Creates a source over a resolved `wave` config.
  VoiceFrameSource(this.config);

  /// The `wave` config for the active tuning.
  final ResolvedOrbConfig config;

  /// Current state (mutable; changing it never rebuilds the widget tree).
  VoiceOrbState state = VoiceOrbState.idle;

  /// Externally supplied level in 0…1.
  double intensity = 0;

  double _energy = 0.1;
  double _scan = 0;
  double _phase = 0;
  double _lastT = double.nan;

  /// Jump straight to the targets on the next build instead of easing — used
  /// on first build and whenever time is frozen (paused / reduced motion),
  /// where there are no frames to ease across.
  bool snap = true;

  @override
  void build(FrameBuilder fb, double size, double t) {
    var dt = _lastT.isNaN ? 0.0 : t - _lastT;
    if (dt < 0) dt = 0;
    if (dt > 0.5) dt = 0.5; // resuming after a pause: don't integrate the gap
    _lastT = t;

    final level = intensity.clamp(0.0, 1.0);
    final syl = 0.5 + 0.5 * math.sin(t * 3.1 + math.sin(t * 0.9) * 2);
    final targetEnergy = switch (state) {
      VoiceOrbState.idle => 0.1,
      VoiceOrbState.listening => 0.2 + 0.8 * level,
      VoiceOrbState.processing => 0.45,
      VoiceOrbState.speaking => (0.25 + 0.75 * level) * (0.55 + 0.45 * syl),
    };
    final targetScan = state == VoiceOrbState.processing ? 1.0 : 0.0;
    if (snap) {
      snap = false;
      _energy = targetEnergy;
      _scan = targetScan;
      _phase = t; // frozen frames look like the listening wave at time t
    } else {
      final k = 1 - math.exp(-dt * 1.2);
      _energy += (targetEnergy - _energy) * k;
      _scan += (targetScan - _scan) * k;
    }
    _phase += dt * (0.5 + 0.8 * _energy);

    _frame(fb, size, t);
  }

  void _frame(FrameBuilder fb, double size, double t) {
    final o = config.opts;
    fb.begin();
    final cx = size / 2;
    final cy = size / 2;
    final bigR = (size / 2) * 0.874;
    final pt = fb.proj..set(t * 0.18, 0.38, cx, cy, 1);
    final rs = radiusScale(size, o.g('rsPow', 0.6));
    final rBase = o.g('rBase', 0.6);
    final rDepth = o.g('rDepth', 1.7);
    final amp = 0.12 + 0.88 * _energy;
    final p = _phase;
    final scan = _scan;
    final scanAngle = t * 1.6;

    final rings = o.g('rings', 15).toInt();
    final lonDensity = o.g('lonDensity', 40);
    for (var ri = 0; ri <= rings; ri++) {
      final lat = -math.pi / 2 + (ri / rings) * math.pi;
      final cosLat = math.cos(lat);
      final sinLat = math.sin(lat);
      final w = (0.62 * math.sin(p * 2.1 - ri * 0.52) + 0.38 * math.sin(p * 1.27 + ri * 0.83)) * amp;
      final rr = bigR * (0.88 + 0.105 * w);
      final lonCount = math.max(1, (cosLat.abs() * lonDensity + 0.5).floor());
      final crest = math.max(0.0, w);
      for (var lj = 0; lj < lonCount; lj++) {
        final lon = (lj / lonCount) * 2 * math.pi;
        pt.project(cosLat * math.cos(lon) * rr, sinLat * rr, cosLat * math.sin(lon) * rr);
        final depth = (pt.z / bigR + 1) / 2;
        var boost = 0.0;
        if (scan > 0.001) {
          final d = angleDelta(lon + t * 0.18, scanAngle);
          boost = math.exp(-(d * d) / 0.18) * math.max(0.0, pt.z / bigR);
        }
        fb.dot(
          pt.x,
          pt.y,
          pt.z,
          ((rBase + rDepth * depth) * (1 + 0.4 * crest) + scan * boost) * rs,
          0.66 - 0.56 * depth - 0.1 * crest,
          1 - 0.55 * scan * (1 - math.min(1.0, boost)),
        );
      }
    }
    fb.finalize(o.g('rMin', 0.3));
  }
}
