import 'dart:math' as math;

import '../engine/particle_system.dart';
import '../engine/projection.dart';
import '../models/thinking_orb_config.dart';

/// `connecting` — a constellation wires itself. Nodes drift on the sphere
/// under slow value noise; any pair closer than `thr` grows an edge, and
/// bright packets run along randomly re-picked node pairs.
void frameWeb(FrameBuilder fb, double size, double t, ModeOpts o) {
  fb.begin();
  final cx = size / 2;
  final cy = size / 2;
  final bigR = (size / 2) * 0.8 * o.g('spread', 1);
  // the projector carries the radius as its scale, so node vectors stay
  // unit-length and distances below are in unit-sphere space
  final pt = fb.proj..set(t * 0.12, 0.32, cx, cy, bigR);
  final rs = radiusScale(size, o.g('rsPow', 0.6));

  final nodeN = o.g('nodeN', 30).toInt();
  final thr = o.g('thr', 0.72);
  final nodeR = o.g('nodeR', 1.4);
  final nodeRDepth = o.g('nodeRDepth', 1.8);
  final lineW = o.g('lineW', 0.8);

  // nodes: fib lattice + slow noise wander, renormalised to the surface
  final nodes = fb.scratch(0, nodeN * 3);
  final dir = fb.scratch(1, 3);
  for (var i = 0; i < nodeN; i++) {
    fibDir(i, nodeN, dir);
    final x = dir[0] + 0.3 * (vnoise(i * 0.31 + 9, t * 0.24) - 0.5) * 2;
    final y = dir[1] + 0.3 * (vnoise(i * 0.53 + 27, t * 0.21) - 0.5) * 2;
    final z = dir[2] + 0.3 * (vnoise(i * 0.77 + 55, t * 0.27) - 0.5) * 2;
    final l = math.sqrt(x * x + y * y + z * z);
    nodes[i * 3] = x / l;
    nodes[i * 3 + 1] = y / l;
    nodes[i * 3 + 2] = z / l;
  }

  // edges between close neighbours, alpha by proximity + depth
  for (var i = 0; i < nodeN; i++) {
    for (var j = i + 1; j < nodeN; j++) {
      final dx = nodes[i * 3] - nodes[j * 3];
      final dy = nodes[i * 3 + 1] - nodes[j * 3 + 1];
      final dz = nodes[i * 3 + 2] - nodes[j * 3 + 2];
      final dist = math.sqrt(dx * dx + dy * dy + dz * dz);
      if (dist >= thr) continue;
      pt.project(nodes[i * 3], nodes[i * 3 + 1], nodes[i * 3 + 2]);
      final x1 = pt.x, y1 = pt.y, z1 = pt.z;
      pt.project(nodes[j * 3], nodes[j * 3 + 1], nodes[j * 3 + 2]);
      final depth = ((z1 + pt.z) / 2 + 1) / 2;
      fb.line(x1, y1, pt.x, pt.y, 0.42, (1 - dist / thr) * (0.3 + 0.55 * depth),
          math.max(0.6, lineW * rs));
    }
  }

  for (var i = 0; i < nodeN; i++) {
    pt.project(nodes[i * 3], nodes[i * 3 + 1], nodes[i * 3 + 2]);
    final depth = (pt.z + 1) / 2;
    final pulse = 1 + 0.25 * math.sin(t * 1.4 + i * 2.7);
    fb.dot(pt.x, pt.y, pt.z, (nodeR + nodeRDepth * depth) * pulse * rs, 0.55 - 0.45 * depth);
  }

  // signals: bright packets running between paired nodes
  final signals = o.g('signals', 5).toInt();
  for (var s = 0; s < signals; s++) {
    final seg = (t * 0.55 + s * 7.31).floorToDouble();
    final a = (hashD(seg, s * 3.1 + 1.7) * nodeN).floor();
    final b = (hashD(seg, s * 5.7 + 4.2) * nodeN).floor();
    if (a == b) continue;
    final f = frac(t * 0.55 + s * 7.31);
    final x = lerp(nodes[a * 3], nodes[b * 3], f);
    final y = lerp(nodes[a * 3 + 1], nodes[b * 3 + 1], f);
    final z = lerp(nodes[a * 3 + 2], nodes[b * 3 + 2], f);
    final l = math.max(1e-6, math.sqrt(x * x + y * y + z * z));
    pt.project(x / l, y / l, z / l);
    final depth = (pt.z + 1) / 2;
    fb.dot(pt.x, pt.y, pt.z, (nodeR * 1.5 + nodeRDepth * depth) * rs, 0.05, 0.5 + 0.5 * depth);
  }

  fb.finalize(o.g('rMin', 0.3));
}
