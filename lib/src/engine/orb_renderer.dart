import 'package:flutter/widgets.dart';

import '../models/thinking_orb_config.dart';
import '../models/thinking_orb_state.dart';
import '../theme/colors.dart';
import 'animation_clock.dart';
import 'mode_frames.dart';
import 'particle_system.dart';

/// Produces one instant of geometry into a [FrameBuilder].
abstract class OrbFrameSource {
  /// Const constructor for subclasses.
  const OrbFrameSource();

  /// Builds the frame for side length [size] at time [t].
  void build(FrameBuilder fb, double size, double t);
}

/// Frame source for the nine preset states.
class PresetFrameSource extends OrbFrameSource {
  /// Creates a source from a resolved config.
  PresetFrameSource(this.config, {this.shape = ThinkingOrbShape.cycle})
      : _frame = modeFrameFor(config.mode),
        _opts = shape == ThinkingOrbShape.cycle || config.mode != OrbMode.morph
            ? config.opts
            : {...config.opts, 'holdShape': (shape.index - 1).toDouble()};

  /// The resolved (mode × tuning) config.
  final ResolvedOrbConfig config;

  /// Outline for the `shaping` state (ignored by every other state).
  final ThinkingOrbShape shape;
  final ModeFrame _frame;
  final ModeOpts _opts;

  @override
  void build(FrameBuilder fb, double size, double t) => _frame(fb, size, t, _opts);

  @override
  bool operator ==(Object other) =>
      other is PresetFrameSource && identical(other.config, config) && other.shape == shape;

  @override
  int get hashCode => Object.hash(config, shape);
}

/// Which depth half of a frame a painter draws. Splitting at z = 0 lets an
/// image sit *inside* the orb: far dots behind it, near dots in front.
enum OrbLayer {
  /// Everything.
  all,

  /// Far side only (z < 0), plus the edge lines.
  back,

  /// Near side only (z ≥ 0).
  front,
}

/// Paints an orb frame. Repaints are driven by [timeline] alone; no widget
/// rebuilds happen while animating.
class OrbPainter extends CustomPainter {
  /// Creates a painter.
  OrbPainter({
    required this.timeline,
    required this.builder,
    required this.source,
    required this.dark,
    required this.colors,
    this.layer = OrbLayer.all,
  }) : super(repaint: timeline);

  /// Animation time.
  final OrbTimeline timeline;

  /// Frame storage, owned by the widget state and shared across layers.
  final FrameBuilder builder;

  /// Geometry source.
  final OrbFrameSource source;

  /// Dark substrate (light ink).
  final bool dark;

  /// Palette.
  final ThinkingOrbColors colors;

  /// Depth half to draw.
  final OrbLayer layer;

  final Paint _fill = Paint()..style = PaintingStyle.fill;
  final Paint _stroke = Paint()..style = PaintingStyle.stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final side = size.shortestSide;
    if (side <= 0) return;
    final t = timeline.t;
    if (builder.builtAt != t ||
        builder.builtSide != side ||
        builder.builtSource != source) {
      source.build(builder, side, t);
      builder
        ..builtAt = t
        ..builtSide = side
        ..builtSource = source;
    }
    final ink = InkPalette.of(colors, dark);

    if (layer != OrbLayer.front) {
      for (final l in builder.lines) {
        _stroke
          ..color = ink.at(l.white, l.a)
          ..strokeWidth = l.w;
        canvas.drawLine(Offset(l.x1, l.y1), Offset(l.x2, l.y2), _stroke);
      }
    }
    for (final d in builder.dots) {
      if (layer == OrbLayer.back && d.z >= 0) continue;
      if (layer == OrbLayer.front && d.z < 0) continue;
      _fill.color = ink.at(d.white, d.a);
      canvas.drawCircle(Offset(d.x, d.y), d.r, _fill);
    }
  }

  @override
  bool shouldRepaint(OrbPainter old) =>
      old.timeline != timeline ||
      old.builder != builder ||
      old.source != source ||
      old.dark != dark ||
      old.colors != colors ||
      old.layer != layer;
}
