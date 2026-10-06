import 'dart:math' as math;

/// Reusable spin + tilt + orthographic projection. Allocation-free: results
/// are read from [x], [y], [z] after calling [project].
class Projector {
  double _st = 0, _ct = 1, _sy = 0, _cyw = 1, _cx = 0, _cy = 0, _scale = 1;

  /// Projected screen x.
  double x = 0;

  /// Projected screen y.
  double y = 0;

  /// Depth after rotation (positive = toward the viewer).
  double z = 0;

  /// Configures yaw/tilt (radians), centre and scale.
  void set(double yaw, double tilt, double cx, double cy, double scale) {
    _st = math.sin(tilt);
    _ct = math.cos(tilt);
    _sy = math.sin(yaw);
    _cyw = math.cos(yaw);
    _cx = cx;
    _cy = cy;
    _scale = scale;
  }

  /// Projects (px, py, pz) into [x], [y], [z].
  void project(double px, double py, double pz) {
    final x1 = px * _cyw + pz * _sy;
    final z1 = -px * _sy + pz * _cyw;
    final y1 = py * _ct - z1 * _st;
    z = py * _st + z1 * _ct;
    x = _cx + x1 * _scale;
    y = _cy - y1 * _scale;
  }
}

/// Linear interpolation.
double lerp(double a, double b, double f) => a + (b - a) * f;

/// Fractional part.
double frac(double x) => x - x.floorToDouble();

/// Deterministic hash in [0, 1).
double hashD(double a, double b) {
  final h = math.sin(a * 12.9898 + b * 78.233) * 43758.5453;
  return h - h.floorToDouble();
}

/// Value noise on a 2-D lattice.
double vnoise(double x, double y) {
  final xi = x.floorToDouble();
  final yi = y.floorToDouble();
  var fx = x - xi;
  var fy = y - yi;
  fx = fx * fx * (3 - 2 * fx);
  fy = fy * fy * (3 - 2 * fy);
  final a = hashD(xi, yi);
  final b = hashD(xi + 1, yi);
  final c = hashD(xi, yi + 1);
  final d = hashD(xi + 1, yi + 1);
  return a + (b - a) * fx + (c - a) * fy + (a - b - c + d) * fx * fy;
}

/// Golden angle used by the Fibonacci lattice.
final double goldenAngle = math.pi * (3 - math.sqrt(5));

/// Writes the i-th of n Fibonacci-lattice directions into [out] (3 values).
void fibDir(int i, int n, List<double> out) {
  final y = 1 - (2 * (i + 0.5)) / n;
  final rad = math.sqrt(1 - y * y);
  final a = i * goldenAngle;
  out[0] = rad * math.cos(a);
  out[1] = y;
  out[2] = rad * math.sin(a);
}

/// Shortest signed angular distance, wrapped to (-π, π].
double angleDelta(double a, double b) =>
    math.atan2(math.sin(a - b), math.cos(a - b));

/// Dot radii were tuned for a 300pt frame; sub-linear scaling keeps small
/// orbs legible.
double radiusScale(double size, double pow) =>
    math.pow(size / 300, pow).toDouble();
