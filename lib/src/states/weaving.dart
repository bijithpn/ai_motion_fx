import 'dart:math' as math;

import '../engine/particle_system.dart';
import '../engine/projection.dart';
import '../models/thinking_orb_config.dart';

/// `weaving` — three strands plait around the sphere. Each strand runs pole
/// to pole on a helix; a radial breathing term makes them trade places.
void frameBraid(FrameBuilder fb, double size, double t, ModeOpts o) {
  fb.begin();
  final cx = size / 2;
  final cy = size / 2;
  final bigR = (size / 2) * 0.76;
  final pt = fb.proj..set(t * 0.4, 0.3, cx, cy, 1);
  final rs = radiusScale(size, o.g('rsPow', 0.6));

  final ghostN = o.g('ghostN', 150).toInt();
  final dir = fb.scratch(1, 3);
  for (var i = 0; i < ghostN; i++) {
    fibDir(i, ghostN, dir);
    pt.project(dir[0] * bigR, dir[1] * bigR, dir[2] * bigR);
    final depth = (pt.z / bigR + 1) / 2;
    fb.dot(pt.x, pt.y, pt.z, 0.8 * rs, 0.78, 0.1 + 0.22 * depth);
  }

  final strandN = o.g('strandN', 52).toInt();
  final turns = o.g('turns', 3);
  final rBase = o.g('rBase', 1.2);
  final rDepth = o.g('rDepth', 1.8);
  for (var s = 0; s < 3; s++) {
    final phase = (s / 3) * 2 * math.pi;
    for (var i = 0; i < strandN; i++) {
      // u walks pole to pole; the frac() drift slides the whole strand along
      final u = (frac(i / strandN + t * 0.045) * 2 - 1) * 0.96;
      final surf = math.sqrt(math.max(0.0, 1 - u * u));
      final endFade = math.min(1.0, (1 - u.abs()) / 0.1);
      final a = u * math.pi * turns + phase;
      // radial breathing: strands trade places — the over/under of a plait
      final weave = 1 + 0.075 * math.sin(u * math.pi * turns * 2 + phase * 2 + t * 0.8);
      final rr = surf * bigR * weave;
      pt.project(math.cos(a) * rr, u * bigR * weave, math.sin(a) * rr);
      final depth = (pt.z / bigR + 1) / 2;
      fb.dot(pt.x, pt.y, pt.z, (rBase + rDepth * depth) * rs, 0.55 - 0.45 * depth,
          endFade * (0.45 + 0.55 * depth));
    }
  }
  fb.finalize(o.g('rMin', 0.3));
}
