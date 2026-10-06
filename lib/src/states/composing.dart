import 'dart:math' as math;

import '../engine/particle_system.dart';
import '../engine/projection.dart';
import '../models/thinking_orb_config.dart';

/// `composing` (ribbon) and `breathing` (ring, via the `faceOn` flag) — an
/// undulating sash of parallel strands riding a great circle. The tuned
/// presets freeze the 3D tumble (`spin` 0), leaving the travelling
/// undulation. Face-on instead modulates the in-plane radius so lobes swell
/// outward and pinch inward — a ring slowly morphing.
void frameRibbon(FrameBuilder fb, double size, double t, ModeOpts o) {
  fb.begin();
  final cx = size / 2;
  final cy = size / 2;
  final bigR = (size / 2) * 0.78;
  final spin = o.g('spin', 1);
  const camTilt = 0.3;
  final pt = fb.proj..set(t * 0.1 * spin, camTilt, cx, cy, 1);
  final rs = radiusScale(size, o.g('rsPow', 0.6));
  final faceOn = o.g('faceOn', 0) != 0;

  final ghostN = o.g('ghostN', 150).toInt();
  final dir = fb.scratch(1, 3);
  for (var i = 0; i < ghostN; i++) {
    fibDir(i, ghostN, dir);
    pt.project(dir[0] * bigR, dir[1] * bigR, dir[2] * bigR);
    final depth = (pt.z / bigR + 1) / 2;
    fb.dot(pt.x, pt.y, pt.z, 0.8 * rs, 0.78, 0.1 + 0.22 * depth);
  }

  // The band plane, precessing (frozen when spin = 0). Face-on sets
  // ta = -camTilt so the projection's vertical squash is 1 and the band
  // reads as a true circle rather than a tilted ellipse.
  final ya = t * 0.24 * spin;
  final ta = faceOn ? -camTilt : 0.55 + 0.3 * math.sin(t * 0.18) * spin;
  final ux = math.cos(ya);
  const uy = 0.0;
  final uz = math.sin(ya);
  final vx = -uz * math.sin(ta);
  final vy = math.cos(ta);
  final vz = ux * math.sin(ta);
  // plane normal n = u × v
  final nx = uy * vz - uz * vy;
  final ny = uz * vx - ux * vz;
  final nz = ux * vy - uy * vx;

  // Radial lobes swell past R, so pull the base radius in by (most of) the
  // wobble amplitude to keep the silhouette inside the frame.
  final wobMul = o.g('wobMul', 1);
  final wobAmp = 0.23 * wobMul;
  final baseR = faceOn ? bigR / (1 + 0.85 * wobAmp) : bigR;

  final baseLanes = o.g('lanes', 5);
  final segs = o.g('segs', 88).toInt();
  final lanes = math.max(1, (baseLanes * o.g('bandMul', 1) + 0.5).floor());
  final rBase = o.g('rBase', 1.1);
  final rDepth = o.g('rDepth', 1.7);
  for (var w = 0; w < lanes; w++) {
    final laneOff = (w - (lanes - 1) / 2) * 0.075;
    final edge = (w - (lanes - 1) / 2).abs() / math.max(1.0, (lanes - 1) / 2);
    for (var k = 0; k < segs; k++) {
      final a = (k / segs) * 2 * math.pi;
      final ca = math.cos(a);
      final sa = math.sin(a);
      // the undulation: two travelling waves along the band
      final wob =
          (0.16 * math.sin(a * 3 - t * 1.7 + w * 0.22) + 0.07 * math.sin(a * 5 + t * 1.1)) * wobMul;
      final radial = faceOn ? 1 + wob : 1.0;
      final off = faceOn ? laneOff : laneOff + wob;
      final x = ux * ca + vx * sa + nx * off;
      final y = uy * ca + vy * sa + ny * off;
      final z = uz * ca + vz * sa + nz * off;
      final l = math.sqrt(x * x + y * y + z * z);
      final rr = baseR * radial;
      pt.project((x / l) * rr, (y / l) * rr, (z / l) * rr);
      final depth = (pt.z / bigR + 1) / 2;
      fb.dot(pt.x, pt.y, pt.z, (rBase + rDepth * depth) * (1 - 0.25 * edge) * rs,
          0.52 - 0.44 * depth + 0.18 * edge, 0.4 + 0.6 * depth);
    }
  }
  fb.finalize(o.g('rMin', 0.3));
}
