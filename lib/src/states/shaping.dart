import 'dart:math' as math;

import '../engine/particle_system.dart';
import '../models/thinking_orb_config.dart';

/// A closed outline parameterised by normalised arc length (top-centre start,
/// clockwise). Writes the point into [x]/[y].
abstract class _OutlinePath {
  double x = 0;
  double y = 0;
  void at(double f);
}

class _Circle extends _OutlinePath {
  @override
  void at(double f) {
    final a = -math.pi / 2 + f * 2 * math.pi;
    x = math.cos(a) * 0.24;
    y = math.sin(a) * 0.24;
  }
}

class _Poly extends _OutlinePath {
  _Poly(this.verts) {
    final v = verts.length;
    for (var i = 0; i < v; i++) {
      final a = verts[i];
      final b = verts[(i + 1) % v];
      final l = math.sqrt((b.$1 - a.$1) * (b.$1 - a.$1) + (b.$2 - a.$2) * (b.$2 - a.$2));
      _len.add(l);
      _total += l;
    }
  }

  final List<(double, double)> verts;
  final List<double> _len = [];
  double _total = 0;

  @override
  void at(double f) {
    final v = verts.length;
    var target = f * _total;
    var i = 0;
    while (target > _len[i] && i < v - 1) {
      target -= _len[i];
      i++;
    }
    final a = verts[i];
    final b = verts[(i + 1) % v];
    final ff = _len[i] != 0 ? math.min(1.0, target / _len[i]) : 0.0;
    x = a.$1 + (b.$1 - a.$1) * ff;
    y = a.$2 + (b.$2 - a.$2) * ff;
  }
}

final _OutlinePath _circle = _Circle();
final _OutlinePath _triangle = _Poly(const [(0.0, -0.26), (0.24, 0.16), (-0.24, 0.16)]);
// 5-vertex walk so the path STARTS at top-centre like the other shapes
final _OutlinePath _square =
    _Poly(const [(0, -0.2), (0.2, -0.2), (0.2, 0.2), (-0.2, 0.2), (-0.2, -0.2)]);
final List<_OutlinePath> _cycle = [_circle, _triangle, _square];

const double _hold = 1.4;
const double _morph = 0.9;
const double _seg = _hold + _morph;
const int _samples = 160;

double _smoothE(double x) => x * x * (3 - 2 * x);

/// `shaping` — a dotted outline cycling circle → triangle → square → circle.
/// Each frame blends the two neighbouring outlines, then lays the dots evenly
/// along the blended path so spacing stays uniform at every instant.
void frameMorph(FrameBuilder fb, double size, double t, ModeOpts o) {
  fb.begin();
  final k = _cycle.length;
  // `holdShape` (0 circle, 1 triangle, 2 square) pins one outline: the same
  // frames the cycle shows during that shape's hold, indefinitely.
  final pinned = o.g('holdShape', -1).toInt();
  final int ki;
  final double local;
  final double m;
  if (pinned >= 0) {
    ki = pinned;
    local = t % _seg;
    m = 0;
  } else {
    final tc = t % (_seg * k);
    ki = (tc / _seg).floor();
    local = tc - ki * _seg;
    m = local > _hold ? _smoothE((local - _hold) / _morph) : 0.0;
  }
  final sprd = o.g('spread', 1);

  final pA = _cycle[ki];
  final pB = _cycle[(ki + 1) % k];
  final pts = fb.scratch(0, _samples * 2);
  final lens = fb.scratch(1, _samples);
  for (var i = 0; i < _samples; i++) {
    final f = i / _samples;
    pA.at(f);
    final ax = pA.x, ay = pA.y;
    pB.at(f);
    pts[i * 2] = (ax + (pB.x - ax) * m) * sprd;
    pts[i * 2 + 1] = (ay + (pB.y - ay) * m) * sprd;
  }
  var total = 0.0;
  for (var i = 0; i < _samples; i++) {
    final j = (i + 1) % _samples;
    final dx = pts[j * 2] - pts[i * 2];
    final dy = pts[j * 2 + 1] - pts[i * 2 + 1];
    final l = math.sqrt(dx * dx + dy * dy);
    lens[i] = l;
    total += l;
  }

  // dot radius depends ONLY on rDot (the size knob); the count sets the gaps.
  final n = math.max(6, (34 * o.g('iconD', 1) + 0.5).floor());
  final re = o.g('rDot', 0.021) * 1.35 * sprd;
  final pulse = 1 + 0.02 * math.sin(local * 3.1);

  final c2 = size / 2;
  var seg = 0;
  var acc = 0.0;
  for (var k2 = 0; k2 < n; k2++) {
    final target = (k2 / n) * total;
    while (acc + lens[seg] < target && seg < _samples - 1) {
      acc += lens[seg];
      seg++;
    }
    final j = (seg + 1) % _samples;
    final f = lens[seg] != 0 ? math.min(1.0, (target - acc) / lens[seg]) : 0.0;
    final x = (pts[seg * 2] + (pts[j * 2] - pts[seg * 2]) * f) * pulse;
    final y = (pts[seg * 2 + 1] + (pts[j * 2 + 1] - pts[seg * 2 + 1]) * f) * pulse;
    fb.dot(c2 + x * size, c2 + y * size, 0, math.max(0.35, re * size), 0.1);
  }
  fb.finalize(o.g('rMin', 0.25));
}
