import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../engine/glow_clock.dart';
import '../theme/glow_variant.dart';
import '../theme/theme.dart';
import 'thinking_orb.dart' show kReducedMotionTime;

/// Look and weight of a [ThinkingBeam].
enum ThinkingBeamSize {
  /// A full beam: bright edge, outer bloom and an inner glow.
  md,

  /// A smaller, tighter beam with a light bloom.
  sm,

  /// A thin line of light and nothing else. Good for dense UIs.
  line,

  /// The whole border glows in colour and breathes, lighting the inside.
  pulseInner,

  /// The whole border glows in colour and breathes, spilling outward.
  pulseOutside;

  /// Short name used in docs and demos, e.g. `pulse-inner`.
  String get label => switch (this) {
        ThinkingBeamSize.md => 'md',
        ThinkingBeamSize.sm => 'sm',
        ThinkingBeamSize.line => 'line',
        ThinkingBeamSize.pulseInner => 'pulse-inner',
        ThinkingBeamSize.pulseOutside => 'pulse-outside',
      };
}

/// An animated glow that rides around the border of any widget.
///
/// A comet of colour travels the child's outline at an even speed (it follows
/// the real border, so it doesn't speed up on the short sides of a wide
/// card). Depending on [size] it also lights the area just outside the edge,
/// just inside it, or both.
///
/// ```dart
/// ThinkingBeam(
///   size: ThinkingBeamSize.md,
///   colorVariant: ThinkingGlowVariant.colorful,
///   strength: 0.8,
///   borderRadius: BorderRadius.circular(20),
///   child: MyCard(),
/// )
/// ```
///
/// Leave a few pixels of room around the child: the outer bloom is drawn past
/// its bounds and would be cut off by a parent that clips.
class ThinkingBeam extends StatefulWidget {
  /// Creates a beam around [child].
  const ThinkingBeam({
    super.key,
    required this.child,
    this.size = ThinkingBeamSize.md,
    this.colorVariant = ThinkingGlowVariant.colorful,
    this.colors,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.theme = ThinkingOrbTheme.auto,
    this.strength = 0.85,
    this.duration = const Duration(milliseconds: 3200),
    this.speed = 1,
    this.paused = false,
    this.reducedMotion,
  });

  /// The widget the beam travels around. Its corners should match
  /// [borderRadius].
  final Widget child;

  /// Weight of the effect, see [ThinkingBeamSize].
  final ThinkingBeamSize size;

  /// Named colour set. Ignored when [colors] is given.
  final ThinkingGlowVariant colorVariant;

  /// Your own colours; the beam blends across them from tail to head.
  final List<Color>? colors;

  /// Corner radius of the child. Match it so the beam hugs the border.
  final BorderRadius borderRadius;

  /// Light or dark surface. `auto` follows the app theme.
  final ThinkingOrbTheme theme;

  /// Glow intensity, 0–1.
  final double strength;

  /// Time for one lap at `speed: 1`.
  final Duration duration;

  /// Speed multiplier.
  final double speed;

  /// Freezes the beam on the current frame.
  final bool paused;

  /// Forces (true) or disables (false) the static reduced-motion frame.
  /// `null` follows the platform accessibility setting.
  final bool? reducedMotion;

  @override
  State<ThinkingBeam> createState() => _ThinkingBeamState();
}

class _ThinkingBeamState extends State<ThinkingBeam> with SingleTickerProviderStateMixin {
  late final GlowClock _clock = GlowClock(this);

  void _sync() {
    final reduced = resolveReducedMotion(context, widget.reducedMotion);
    _clock.speed = widget.speed;
    if (reduced) _clock.time = kReducedMotionTime;
    _clock.setRunning(!widget.paused && !reduced);
    _clock.poke();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ThinkingBeam old) {
    super.didUpdateWidget(old);
    _sync();
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.theme.resolveDark(context);
    final colors = widget.colors != null && widget.colors!.isNotEmpty
        ? widget.colors!
        : widget.colorVariant.colors(dark: dark);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(painter: _BeamPainter(this, colors, dark)),
            ),
          ),
        ),
      ],
    );
  }
}

class _BeamPainter extends CustomPainter {
  _BeamPainter(this.s, this.colors, this.dark) : super(repaint: s._clock);

  final _ThinkingBeamState s;
  final List<Color> colors;
  final bool dark;

  // Cache the border path and its metric per size / radius.
  Size? _cachedSize;
  BorderRadius? _cachedRadius;
  ui.PathMetric? _metric;
  double _length = 0;

  void _ensurePath(Size size, BorderRadius radius) {
    if (_cachedSize == size && _cachedRadius == radius && _metric != null) return;
    final path = Path()..addRRect(radius.toRRect(Offset.zero & size));
    _metric = path.computeMetrics().first;
    _length = _metric!.length;
    _cachedSize = size;
    _cachedRadius = radius;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final wd = s.widget;
    final radius = wd.borderRadius;
    _ensurePath(size, radius);
    final metric = _metric!;
    final len = _length;

    final lapSeconds = (wd.duration.inMicroseconds / 1e6).clamp(0.2, 60.0);
    final t = s._clock.time;
    final strength = wd.strength.clamp(0.0, 1.0);
    final pulse = wd.size == ThinkingBeamSize.pulseInner || wd.size == ThinkingBeamSize.pulseOutside;
    final rrect = radius.toRRect(Offset.zero & size);

    // (stroke px, arc as a fraction of the border, outer blur, inner glow width)
    final (stroke, arc, outer, inner) = switch (wd.size) {
      ThinkingBeamSize.md => (2.0, 0.42, 14.0, 20.0),
      ThinkingBeamSize.sm => (1.5, 0.3, 6.0, 0.0),
      ThinkingBeamSize.line => (1.2, 0.24, 0.0, 0.0),
      ThinkingBeamSize.pulseInner => (1.5, 1.0, 0.0, 26.0),
      ThinkingBeamSize.pulseOutside => (1.5, 1.0, 20.0, 0.0),
    };

    final blend = dark ? BlendMode.plus : BlendMode.srcOver;
    final breath = pulse ? 0.55 + 0.45 * (0.5 + 0.5 * math.sin(t * 2.2)) : 1.0;
    final gain = strength * breath;

    // Faint track so the shape reads even where the beam isn't.
    canvas.drawRRect(
      rrect.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = (dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000)).withValues(alpha: 0.07),
    );

    // Segments along the border: each gets its own colour and alpha, which
    // makes the comet. The head leads; alpha ramps up toward it.
    final head = ((t / lapSeconds) % 1.0) * len;
    final arcLen = pulse ? len : len * arc;

    // Draws the comet as a run of short strokes, each with its own colour and
    // alpha. They go into a layer with `BlendMode.src`, so overlapping ends
    // replace each other instead of stacking into visible ticks.
    void ring(int segments, double width, double alphaScale, MaskFilter? blur, {BlendMode? mode}) {
      final bounds = (Offset.zero & size).inflate(width + (blur == null ? 4 : 80));
      canvas.saveLayer(bounds, Paint()..blendMode = mode ?? blend);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..blendMode = BlendMode.src
        ..maskFilter = blur;
      final segLen = arcLen / segments;
      for (var i = 0; i < segments; i++) {
        final u = (i + 0.5) / segments; // 0 = tail … 1 = head
        final double alpha;
        final Color color;
        if (pulse) {
          alpha = 0.9;
          color = sampleLoop(colors, u + t * 0.09);
        } else {
          // Soft tail that quickens toward the head, then a short roll-off.
          alpha = math.pow(u, 1.3).toDouble() * (u > 0.97 ? 0.55 + (1 - u) / 0.03 * 0.45 : 1.0);
          color = sampleLoop(colors, 1 - u + t * 0.05);
        }
        final a = (alpha * alphaScale * gain).clamp(0.0, 1.0);
        if (a < 0.01) continue;
        paint.color = color.withValues(alpha: a);
        final start = pulse ? i * segLen : head - arcLen + i * segLen;
        _stroke(canvas, metric, len, start, start + segLen + 1.2, paint);
      }
      canvas.restore();
    }

    // Outer bloom.
    if (outer > 0) {
      ring(pulse ? 36 : 24, stroke * 3.5, pulse ? 0.75 : 1.0, MaskFilter.blur(BlurStyle.normal, outer));
    }

    // Inner glow, clipped to the child's shape.
    if (inner > 0) {
      canvas.save();
      canvas.clipRRect(rrect);
      ring(pulse ? 36 : 24, inner, pulse ? 0.6 : 0.6, MaskFilter.blur(BlurStyle.normal, inner * 0.55));
      canvas.restore();
    }

    // Crisp bright edge on top.
    ring(pulse ? 72 : 48, stroke, 1, null);
    if (wd.size == ThinkingBeamSize.md && !pulse) {
      // A hot white core at the very head for that "lit" look.
      final hot = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.6
        ..strokeCap = StrokeCap.round
        ..blendMode = blend
        ..color = const Color(0xFFFFFFFF).withValues(alpha: 0.75 * gain);
      _stroke(canvas, metric, len, head - len * 0.035, head, hot);
    }
  }

  /// Strokes [metric] from [a] to [b] (arc-length), wrapping past the end.
  void _stroke(Canvas canvas, ui.PathMetric metric, double len, double a, double b, Paint paint) {
    if (b - a <= 0) return;
    var s0 = a % len;
    if (s0 < 0) s0 += len;
    final e0 = s0 + (b - a);
    if (e0 <= len) {
      canvas.drawPath(metric.extractPath(s0, e0), paint);
    } else {
      canvas.drawPath(metric.extractPath(s0, len), paint);
      canvas.drawPath(metric.extractPath(0, e0 - len), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _BeamPainter old) =>
      old.colors != colors || old.dark != dark || old.s != s;
}
