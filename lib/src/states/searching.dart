import 'dart:math' as math;

import '../engine/particle_system.dart';
import '../engine/projection.dart';
import '../models/thinking_orb_config.dart';

/// `searching` — a lat/long dot field; a scan meridian sweeps across it.
void frameGlobe(FrameBuilder fb, double size, double t, ModeOpts o) {
  fb.begin();
  const spin = 0.5;
  final cx = size / 2;
  final cy = size / 2;
  final radius = (size / 2) * 0.82;
  final tilt = 0.4 + 0.06 * math.sin(t * 0.35);
  final pt = fb.proj..set(t * spin, tilt, cx, cy, radius);
  // scan sweeps relative to the spin; scanMul scales that relative rate
  final scan = t * (spin + (1.7 - spin) * o.g('scanMul', 1));
  final rs = radiusScale(size, o.g('rsPow', 0.6));
  final dimBase = o.g('dimBase', 1);
  final rBase = o.g('rBase', 0.6);
  final rDepth = o.g('rDepth', 1.7);
  final rBoost = o.g('rBoost', 1);
  final inkFar = o.g('inkFar', 0.62);
  final inkSpan = o.g('inkSpan', 0.54);

  final latRings = o.g('latRings', 17).toInt();
  final lonDensity = o.g('lonDensity', 44);
  for (var li = 0; li <= latRings; li++) {
    final lat = -math.pi / 2 + (li / latRings) * math.pi;
    final cosLat = math.cos(lat);
    final sinLat = math.sin(lat);
    final lonCount = math.max(1, (cosLat.abs() * lonDensity + 0.5).floor());
    for (var lj = 0; lj < lonCount; lj++) {
      final lon = (lj / lonCount) * 2 * math.pi;
      pt.project(cosLat * math.cos(lon), sinLat, cosLat * math.sin(lon));
      final depth = (pt.z + 1) / 2;
      // the scan: a moving meridian read as a size ripple, not a shine
      final d = angleDelta(lon + t * spin, scan);
      final boost = math.exp(-(d * d) / 0.18) * math.max(0, pt.z);
      fb.dot(
        pt.x,
        pt.y,
        pt.z,
        (rBase + rDepth * depth + rBoost * boost) * rs,
        inkFar - inkSpan * depth,
        // dimBase < 1 fades un-scanned dots so the meridian reads clearly
        dimBase + (1 - dimBase) * math.min(1, boost),
      );
    }
  }
  fb.finalize(o.g('rMin', 0.3));
}
