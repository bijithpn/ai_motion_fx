import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../engine/animation_clock.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// A beam of light travelling around the border of [child].
///
/// Painted directly with a single [CustomPainter] on the shared animation
/// clock — the child is isolated behind a [RepaintBoundary], so the beam
/// repaints at frame rate without rebuilding or repainting the child.
class ThinkingBorderBeam extends StatefulWidget {
  /// Creates a border beam around [child].
  const ThinkingBorderBeam({
    super.key,
    required this.child,
    this.speed = 0.25,
    this.strokeWidth = 2,
    this.borderRadius = 12,
    this.length = 0.3,
    this.opacity = 1,
    this.colors,
    this.theme = ThinkingOrbTheme.auto,
    this.inkColors = ThinkingOrbColors.standard,
    this.paused = false,
    this.reducedMotion,
  });

  /// The widget to frame.
  final Widget child;

  /// Revolutions per second (0.25 = one lap every 4 s).
  final double speed;

  /// Beam thickness in logical pixels.
  final double strokeWidth;

  /// Corner radius of the border the beam follows.
  final double borderRadius;

  /// Beam length as a fraction of the perimeter (0…1).
  final double length;

  /// Peak opacity at the head of the beam (0…1).
  final double opacity;

  /// Optional head → tail colour gradient. Defaults to the theme's ink.
  final List<Color>? colors;

  /// Light/dark ink for the default colour.
  final ThinkingOrbTheme theme;

  /// Palette used for the default colour.
  final ThinkingOrbColors inkColors;

  /// Freezes the beam where it is.
  final bool paused;

  /// Forces / disables the static reduced-motion beam; null follows the platform.
  final bool? reducedMotion;

  @override
  State<ThinkingBorderBeam> createState() => _ThinkingBorderBeamState();
}

class _ThinkingBorderBeamState extends State<ThinkingBorderBeam>
    with SingleTickerProviderStateMixin {
  late final OrbTimeline _timeline = OrbTimeline(this);
  final _BeamTrack _track = _BeamTrack();

  void _sync() {
    final reduced = resolveReducedMotion(context, widget.reducedMotion);
    _timeline.configure(
      rate: widget.speed,
      running: !widget.paused,
      frozenAt: reduced ? 0.125 : null,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ThinkingBorderBeam old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.theme.resolveDark(context);
    final colors = widget.colors ??
        [widget.inkColors.ink(0, dark: dark)];
    return RepaintBoundary(
      child: CustomPaint(
        foregroundPainter: _BeamPainter(
          timeline: _timeline,
          track: _track,
          colors: colors,
          strokeWidth: widget.strokeWidth,
          radius: widget.borderRadius,
          length: widget.length.clamp(0.01, 1.0),
          opacity: widget.opacity.clamp(0.0, 1.0),
        ),
        child: RepaintBoundary(child: widget.child),
      ),
    );
  }
}

/// Caches the border contour so per-frame work is only segment extraction.
class _BeamTrack {
  Size? _size;
  double? _radius;
  double? _inset;
  ui.PathMetric? _metric;

  ui.PathMetric? metric(Size size, double radius, double inset) {
    if (_size != size || _radius != radius || _inset != inset) {
      _size = size;
      _radius = radius;
      _inset = inset;
      final rect = (Offset.zero & size).deflate(inset);
      final path = Path()
        ..addRRect(RRect.fromRectAndRadius(rect, Radius.circular((radius - inset).clamp(0, 1e6))));
      final it = path.computeMetrics().iterator;
      _metric = it.moveNext() ? it.current : null;
    }
    return _metric;
  }
}

class _BeamPainter extends CustomPainter {
  _BeamPainter({
    required this.timeline,
    required this.track,
    required this.colors,
    required this.strokeWidth,
    required this.radius,
    required this.length,
    required this.opacity,
  }) : super(repaint: timeline);

  static const int _slices = 48;

  final OrbTimeline timeline;
  final _BeamTrack track;
  final List<Color> colors;
  final double strokeWidth;
  final double radius;
  final double length;
  final double opacity;

  final Paint _paint = Paint()..style = PaintingStyle.stroke;

  Color _colorAt(double f) {
    if (colors.length == 1) return colors[0];
    final p = f.clamp(0.0, 1.0) * (colors.length - 1);
    final i = p.floor().clamp(0, colors.length - 2);
    return Color.lerp(colors[i], colors[i + 1], p - i)!;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final metric = track.metric(size, radius, strokeWidth / 2);
    if (metric == null) return;
    final total = metric.length;
    final head = (timeline.t - timeline.t.floorToDouble()) * total;
    final seg = total * length / _slices;
    _paint.strokeWidth = strokeWidth;
    for (var i = 0; i < _slices; i++) {
      final f = i / _slices; // 0 at the head → 1 at the tail
      final fade = (1 - f) * (1 - f);
      final c = _colorAt(f);
      _paint
        ..strokeCap = i == 0 ? StrokeCap.round : StrokeCap.butt // soft head
        ..color = c.withValues(alpha: c.a * opacity * fade);
      final start = head - (i + 1) * seg;
      final end = head - i * seg;
      if (start >= 0) {
        canvas.drawPath(metric.extractPath(start, end), _paint);
      } else if (end <= 0) {
        canvas.drawPath(metric.extractPath(total + start, total + end), _paint);
      } else {
        canvas.drawPath(metric.extractPath(total + start, total), _paint);
        canvas.drawPath(metric.extractPath(0, end), _paint);
      }
    }
  }

  @override
  bool shouldRepaint(_BeamPainter old) =>
      old.timeline != timeline ||
      old.colors != colors && !_sameColors(old.colors, colors) ||
      old.strokeWidth != strokeWidth ||
      old.radius != radius ||
      old.length != length ||
      old.opacity != opacity;

  static bool _sameColors(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
