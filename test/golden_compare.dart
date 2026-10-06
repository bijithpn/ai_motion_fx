import 'package:flutter_test/flutter_test.dart';
import 'package:ai_motion_fx/src/engine/particle_system.dart';

/// Asserts [fb] holds the same dots/lines as a golden case.
///
/// [want] / [wantLines] are the flat arrays from the original engine (dot
/// stride 6: x, y, z, r, white, a; line stride 7). Dots are compared in draw
/// order, except that runs of equal depth (|Δz| < 1e-5) are matched as sets:
/// their order has no visual meaning and, in the original, depends on sub-ulp
/// trig noise (the face-on ring sits at z = 0 exactly).
void expectFrameMatches(
  FrameBuilder fb, {
  required List<num> want,
  required List<num> wantLines,
  required int dotCount,
  required int lineCount,
  double tol = 1e-4,
}) {
  expect(fb.dots.length, dotCount, reason: 'dot count');
  expect(fb.lines.length, lineCount, reason: 'line count');
  double w(int i, int j) => want[i * 6 + j].toDouble();
  final n = fb.dots.length;
  var start = 0;
  while (start < n) {
    var end = start + 1;
    while (end < n && (w(end, 2) - w(start, 2)).abs() < 1e-5) {
      end++;
    }
    final unmatched = [for (var i = start; i < end; i++) i];
    for (var i = start; i < end; i++) {
      final d = fb.dots[i];
      final got = [d.x, d.y, d.z, d.r, d.white, d.a];
      final hit = unmatched.indexWhere((k) {
        for (var j = 0; j < 6; j++) {
          if ((got[j] - w(k, j)).abs() > tol) return false;
        }
        return true;
      });
      expect(hit, isNonNegative, reason: 'dot $i (z=${d.z}) has no golden match');
      unmatched.removeAt(hit);
    }
    start = end;
  }
  for (var i = 0; i < fb.lines.length; i++) {
    final l = fb.lines[i];
    final got = [l.x1, l.y1, l.x2, l.y2, l.white, l.a, l.w];
    for (var j = 0; j < 7; j++) {
      expect(got[j], closeTo(wantLines[i * 7 + j].toDouble(), tol), reason: 'line $i field $j');
    }
  }
}
