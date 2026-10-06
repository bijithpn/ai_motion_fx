import 'dart:math' as math;

import '../engine/particle_system.dart';
import '../engine/projection.dart';
import '../models/thinking_orb_config.dart';

class _Move {
  const _Move(this.axis, this.lo, this.hi, this.ang);
  final int axis;
  final double lo;
  final double hi;
  final double ang;
}

final Map<int, List<_Move>> _moveCache = {};

List<_Move> _makeMoves(int count) => _moveCache.putIfAbsent(count, () {
      final moves = <_Move>[];
      for (var i = 0; i < count; i++) {
        final axis = math.min(2, (hashD(i.toDouble(), 2.3) * 3).floor());
        final lo = -1.0 + 0.5 * math.min(3, (hashD(i.toDouble(), 5.9) * 4).floor());
        final dir = hashD(i.toDouble(), 7.7) < 0.5 ? 1 : -1;
        moves.add(_Move(axis, lo, lo + 0.5, dir * math.pi / 2));
      }
      return moves;
    });

/// Fills [amount] with each move's progress and returns the active slot
/// (-1 at rest). Rapid eased moves scramble, then replay in reverse
/// (palindrome) so everything clicks back to solved, rests, repeats.
int _solveCycle(double time, int count, double slotDur, double rest, List<double> amount) {
  final cyc = 2 * count * slotDur + rest;
  final tc = time % cyc;
  for (var i = 0; i < count; i++) {
    amount[i] = 0;
  }
  var active = -1;
  if (tc < 2 * count * slotDur) {
    final slot = (tc / slotDur).floor();
    final p = (tc - slot * slotDur) / slotDur;
    final cl = math.min(1.0, p / 0.7);
    final inv = 1 - cl;
    final ep = 1 - inv * inv * inv; // machine ease-out
    if (slot < count) {
      for (var i = 0; i < slot; i++) {
        amount[i] = 1;
      }
      amount[slot] = ep;
      active = slot;
    } else {
      final u = 2 * count - 1 - slot;
      for (var i = 0; i < u; i++) {
        amount[i] = 1;
      }
      amount[u] = 1 - ep;
      active = u;
    }
  }
  return active;
}

/// `solving` — bands twist in quarter turns: scramble → solve.
void frameRubik(FrameBuilder fb, double size, double t, ModeOpts o) {
  fb.begin();
  final cx = size / 2;
  final cy = size / 2;
  final bigR = (size / 2) * 0.82;
  final pt = fb.proj..set(t * 0.55, 0.35 + 0.1 * math.sin(t * 0.9), cx, cy, bigR);
  final rs = radiusScale(size, o.g('rsPow', 0.6));
  final moveCount = o.g('moveCount', 14).toInt();
  final moves = _makeMoves(moveCount);
  final amount = fb.scratch(0, moveCount);
  final active = _solveCycle(t, moveCount, 0.42, 1.2, amount);
  final rBase = o.g('rBase', 0.6);
  final rDepth = o.g('rDepth', 1.7);
  final rActive = o.g('rActive', 0.3);
  final inkFar = o.g('inkFar', 0.62);
  final inkSpan = o.g('inkSpan', 0.54);

  final latRings = o.g('latRings', 15).toInt();
  final lonDensity = o.g('lonDensity', 40);
  for (var li = 0; li <= latRings; li++) {
    final lat = -math.pi / 2 + (li / latRings) * math.pi;
    final cosLat = math.cos(lat);
    final sinLat = math.sin(lat);
    final lonCount = math.max(1, (cosLat.abs() * lonDensity + 0.5).floor());
    for (var lj = 0; lj < lonCount; lj++) {
      final lon = (lj / lonCount) * 2 * math.pi;
      var x = cosLat * math.cos(lon);
      var y = sinLat;
      var z = cosLat * math.sin(lon);
      var inActive = false;
      for (var i = 0; i < moveCount; i++) {
        if (amount[i] <= 0) continue;
        final mv = moves[i];
        final coord = mv.axis == 0 ? x : (mv.axis == 1 ? y : z);
        if (coord < mv.lo || coord >= mv.hi) continue;
        if (i == active) inActive = true;
        final a = mv.ang * amount[i];
        final ca = math.cos(a);
        final sa = math.sin(a);
        if (mv.axis == 0) {
          final y2 = y * ca - z * sa;
          z = y * sa + z * ca;
          y = y2;
        } else if (mv.axis == 1) {
          final x2 = x * ca + z * sa;
          z = -x * sa + z * ca;
          x = x2;
        } else {
          final x2 = x * ca - y * sa;
          y = x * sa + y * ca;
          x = x2;
        }
      }
      pt.project(x, y, z);
      final depth = (pt.z + 1) / 2;
      // the band being turned inks a touch darker — the "hand"
      fb.dot(
        pt.x,
        pt.y,
        pt.z,
        (rBase + rDepth * depth + (inActive ? rActive : 0)) * rs,
        inkFar - inkSpan * depth - (inActive ? 0.14 : 0),
      );
    }
  }
  fb.finalize(o.g('rMin', 0.3));
}
