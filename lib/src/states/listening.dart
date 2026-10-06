import 'dart:math' as math;

import '../engine/particle_system.dart';
import '../engine/projection.dart';
import '../models/thinking_orb_config.dart';

/// `listening` — a waveform rolls through the latitude rings.
void frameWave(FrameBuilder fb, double size, double t, ModeOpts o) {
  fb.begin();
  final cx = size / 2;
  final cy = size / 2;
  // 0.76 base × 1.15 — the undulation pulls the sphere inward, so wave read
  // ~15% smaller than the other lattice modes; scaled up to match them
  final bigR = (size / 2) * 0.874;
  final pt = fb.proj..set(t * 0.18, 0.38, cx, cy, 1);
  final rs = radiusScale(size, o.g('rsPow', 0.6));
  final rBase = o.g('rBase', 0.6);
  final rDepth = o.g('rDepth', 1.7);

  final rings = o.g('rings', 15).toInt();
  final lonDensity = o.g('lonDensity', 40);
  for (var ri = 0; ri <= rings; ri++) {
    final lat = -math.pi / 2 + (ri / rings) * math.pi;
    final cosLat = math.cos(lat);
    final sinLat = math.sin(lat);
    // two waves, different tempi — organic, never quite repeating
    final w = 0.62 * math.sin(t * 2.1 - ri * 0.52) + 0.38 * math.sin(t * 1.27 + ri * 0.83);
    final rr = bigR * (0.88 + 0.105 * w);
    final lonCount = math.max(1, (cosLat.abs() * lonDensity + 0.5).floor());
    final crest = math.max(0.0, w);
    for (var lj = 0; lj < lonCount; lj++) {
      final lon = (lj / lonCount) * 2 * math.pi;
      pt.project(cosLat * math.cos(lon) * rr, sinLat * rr, cosLat * math.sin(lon) * rr);
      final depth = (pt.z / bigR + 1) / 2;
      fb.dot(
        pt.x,
        pt.y,
        pt.z,
        (rBase + rDepth * depth) * (1 + 0.4 * crest) * rs,
        0.66 - 0.56 * depth - 0.1 * crest,
      );
    }
  }
  fb.finalize(o.g('rMin', 0.3));
}
