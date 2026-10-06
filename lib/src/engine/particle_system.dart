import 'dart:typed_data';

import 'projection.dart';

/// One projected mark. Pooled and mutable — never allocate these per frame.
class Dot {
  /// Screen x.
  double x = 0;

  /// Screen y.
  double y = 0;

  /// Depth.
  double z = 0;

  /// Radius.
  double r = 0;

  /// Ink value: 0 = darkest ink on paper, mirrored on dark themes.
  double white = 0;

  /// Alpha.
  double a = 1;

  /// Insertion order, used as a stable-sort tie-break.
  int seq = 0;
}

/// A stroked edge between two projected points (the `connecting` web).
class Line {
  /// Start x.
  double x1 = 0;

  /// Start y.
  double y1 = 0;

  /// End x.
  double x2 = 0;

  /// End y.
  double y2 = 0;

  /// Ink value.
  double white = 0;

  /// Alpha.
  double a = 1;

  /// Stroke width.
  double w = 1;
}

int _byDepth(Dot a, Dot b) {
  final c = a.z.compareTo(b.z);
  return c != 0 ? c : a.seq.compareTo(b.seq);
}

/// Reusable per-orb frame storage: pooled dots/lines, a shared projector and
/// scratch buffers, so steady-state frames allocate nothing.
class FrameBuilder {
  final List<Dot> _dotPool = [];
  final List<Line> _linePool = [];
  int _dotCount = 0;
  int _lineCount = 0;

  /// Visible dots in draw order (far → near), valid after [finalize].
  final List<Dot> dots = [];

  /// Visible lines, valid after [finalize]. Drawn before dots.
  final List<Line> lines = [];

  /// Shared projector.
  final Projector proj = Projector();

  /// What the current contents were built for; lets several painters share one
  /// computed frame (see [OrbPainter]). NaN/null before the first build.
  double builtAt = double.nan;

  /// Side length of the last build.
  double builtSide = double.nan;

  /// Source of the last build.
  Object? builtSource;

  final Map<int, Float64List> _scratch = {};

  /// A scratch buffer of at least [len] doubles for [slot]. Contents are
  /// undefined; callers must write before reading.
  Float64List scratch(int slot, int len) {
    var b = _scratch[slot];
    if (b == null || b.length < len) {
      b = Float64List(len);
      _scratch[slot] = b;
    }
    return b;
  }

  /// Starts a new frame.
  void begin() {
    _dotCount = 0;
    _lineCount = 0;
  }

  /// Adds a dot.
  void dot(double x, double y, double z, double r, double white, [double a = 1]) {
    final Dot d;
    if (_dotCount < _dotPool.length) {
      d = _dotPool[_dotCount];
    } else {
      d = Dot();
      _dotPool.add(d);
    }
    d
      ..x = x
      ..y = y
      ..z = z
      ..r = r
      ..white = white
      ..a = a
      ..seq = _dotCount;
    _dotCount++;
  }

  /// Adds a line.
  void line(double x1, double y1, double x2, double y2, double white, double a, double w) {
    final Line l;
    if (_lineCount < _linePool.length) {
      l = _linePool[_lineCount];
    } else {
      l = Line();
      _linePool.add(l);
    }
    l
      ..x1 = x1
      ..y1 = y1
      ..x2 = x2
      ..y2 = y2
      ..white = white
      ..a = a
      ..w = w;
    _lineCount++;
  }

  /// Drops invisible marks, clamps radii to [rMin] and z-sorts far → near.
  void finalize(double rMin) {
    dots.clear();
    for (var i = 0; i < _dotCount; i++) {
      final d = _dotPool[i];
      if (d.a < 0.02) continue;
      if (d.r < rMin) d.r = rMin;
      dots.add(d);
    }
    dots.sort(_byDepth);
    lines.clear();
    for (var i = 0; i < _lineCount; i++) {
      final l = _linePool[i];
      if (l.a >= 0.02) lines.add(l);
    }
  }
}
