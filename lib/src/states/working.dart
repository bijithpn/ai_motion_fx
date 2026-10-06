import 'dart:math' as math;

import '../engine/particle_system.dart';
import '../engine/projection.dart';
import '../models/thinking_orb_config.dart';

/// `working` — particles on tilted orbits. No nucleus: ghost paths plus the
/// particles doing the work.
void frameOrbits(FrameBuilder fb, double size, double t, ModeOpts o) {
  fb.begin();
  final cx = size / 2;
  final cy = size / 2;
  final bigR = (size / 2) * 0.82;
  final pt = fb.proj..set(t * 0.12, 0.3, cx, cy, 1);
  final rs = radiusScale(size, o.g('rsPow', 0.6));

  final orbitN = o.g('orbitN', 12).toInt();
  final ghostN = o.g('ghostN', 40).toInt();
  final particles = o.g('particles', 3).toInt();
  final ghostR = o.g('ghostR', 0.9);
  final ghostA = o.g('ghostA', 0.5);
  final partR = o.g('partR', 1.2);
  final partRDepth = o.g('partRDepth', 1.6);

  for (var orb = 0; orb < orbitN; orb++) {
    final h1 = hashD(orb.toDouble(), 1.7);
    final h2 = hashD(orb.toDouble(), 5.2);
    final h3 = hashD(orb.toDouble(), 8.9);
    final ro = bigR * (0.45 + 0.52 * h1);
    final th = h1 * 2 * math.pi;
    final phi = math.acos(2 * h2 - 1);
    // orbit plane basis (u, v ⟂ normal n)
    final nx = math.sin(phi) * math.cos(th);
    final ny = math.cos(phi);
    final nz = math.sin(phi) * math.sin(th);
    var ux = -ny;
    var uy = nx;
    const uz = 0.0;
    final ul = math.max(1e-6, math.sqrt(ux * ux + uy * uy));
    ux /= ul;
    uy /= ul;
    final vx = ny * uz - nz * uy;
    final vy = nz * ux - nx * uz;
    final vz = nx * uy - ny * ux;
    final speed = (0.25 + 0.55 * h3) * (h3 > 0.5 ? 1 : -1);

    // ghost path
    for (var k = 0; k < ghostN; k++) {
      final a = (k / ghostN) * 2 * math.pi;
      final ca = math.cos(a);
      final sa = math.sin(a);
      pt.project((ux * ca + vx * sa) * ro, (uy * ca + vy * sa) * ro, (uz * ca + vz * sa) * ro);
      final depth = (pt.z / ro + 1) / 2;
      fb.dot(pt.x, pt.y, pt.z, ghostR * rs, 0.72, ghostA * (0.4 + 0.6 * depth));
    }
    // the particles doing the work
    for (var m = 0; m < particles; m++) {
      final a = t * speed + (m / particles) * 2 * math.pi + h2 * 6;
      final ca = math.cos(a);
      final sa = math.sin(a);
      pt.project((ux * ca + vx * sa) * ro, (uy * ca + vy * sa) * ro, (uz * ca + vz * sa) * ro);
      final depth = (pt.z / ro + 1) / 2;
      fb.dot(pt.x, pt.y, pt.z, (partR + partRDepth * depth) * rs, 0.3 - 0.22 * depth);
    }
  }
  fb.finalize(o.g('rMin', 0.3));
}
