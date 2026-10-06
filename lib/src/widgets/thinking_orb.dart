import 'package:flutter/widgets.dart';

import '../engine/animation_clock.dart';
import '../engine/orb_renderer.dart';
import '../engine/particle_system.dart';
import '../models/thinking_orb_config.dart';
import '../models/thinking_orb_state.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';

/// The frame the original shows to reduced-motion users.
const double kReducedMotionTime = 0.6;

/// An animated, procedurally drawn thinking indicator.
///
/// ```dart
/// const ThinkingOrb()                                    // working, 64px, auto theme
/// ThinkingOrb(state: ThinkingOrbState.searching)          // pick an animation
/// ThinkingOrb(state: ThinkingOrbState.shaping,
///             shape: ThinkingOrbShape.triangle)           // hold one shape
/// const ThinkingOrb.compact()                             // 20px, inline with text
/// ```
///
/// Each [ThinkingOrbState] is its own hand-tuned animation, rendered with a
/// single [CustomPainter]. Animation time comes from a shared clock, so any
/// number of orbs stay in phase, and repainting never rebuilds widgets.
///
/// Two designs are hand-tuned — 20 and 64 logical pixels. For other [size]s
/// the nearest design is used (split at ≈36px) and dot radii scale with size.
class ThinkingOrb extends StatefulWidget {
  /// Creates a thinking orb.
  const ThinkingOrb({
    super.key,
    this.state = ThinkingOrbState.working,
    this.shape = ThinkingOrbShape.cycle,
    this.size = 64,
    this.theme = ThinkingOrbTheme.auto,
    this.speed = 1.0,
    this.paused = false,
    this.semanticLabel,
    this.colors = ThinkingOrbColors.standard,
    this.reducedMotion,
  });

  /// An inline, text-sized orb (20 logical px, the compact tuning):
  /// `Row(children: [ThinkingOrb.compact(), Text('Thinking…')])`.
  const ThinkingOrb.compact({
    super.key,
    this.state = ThinkingOrbState.working,
    this.shape = ThinkingOrbShape.cycle,
    this.theme = ThinkingOrbTheme.auto,
    this.speed = 1.0,
    this.paused = false,
    this.semanticLabel,
    this.colors = ThinkingOrbColors.standard,
    this.reducedMotion,
  }) : size = 20;

  /// Which animation to show.
  final ThinkingOrbState state;

  /// Outline for [ThinkingOrbState.shaping]: the original morphing cycle, or
  /// one held shape. Ignored by other states.
  final ThinkingOrbShape shape;

  /// Side length in logical pixels.
  final double size;

  /// Light/dark ink. [ThinkingOrbTheme.auto] follows the app theme.
  final ThinkingOrbTheme theme;

  /// Speed multiplier on top of the preset's baked speed.
  final double speed;

  /// Freezes the animation on the current frame.
  final bool paused;

  /// Overrides the default per-state accessibility label.
  final String? semanticLabel;

  /// Ink palette. The default reproduces the original greyscale exactly.
  final ThinkingOrbColors colors;

  /// Forces (true) or disables (false) the static reduced-motion frame.
  /// `null` follows the platform accessibility setting.
  final bool? reducedMotion;

  @override
  State<ThinkingOrb> createState() => _ThinkingOrbState();
}

class _ThinkingOrbState extends State<ThinkingOrb> with SingleTickerProviderStateMixin {
  late final OrbTimeline _timeline = OrbTimeline(this);
  final FrameBuilder _builder = FrameBuilder();
  late PresetFrameSource _source;

  @override
  void initState() {
    super.initState();
    _source = PresetFrameSource(_config(), shape: widget.shape);
  }

  ResolvedOrbConfig _config() =>
      ResolvedOrbConfig.resolve(widget.state, OrbTuning.forSize(widget.size));

  void _sync() {
    final reduced = resolveReducedMotion(context, widget.reducedMotion);
    _timeline.configure(
      rate: _source.config.speed * widget.speed,
      running: !widget.paused,
      frozenAt: reduced ? kReducedMotionTime : null,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ThinkingOrb old) {
    super.didUpdateWidget(old);
    final cfg = _config();
    if (!identical(cfg, _source.config) || widget.shape != _source.shape) {
      _source = PresetFrameSource(cfg, shape: widget.shape);
    }
    _sync();
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticLabel ?? widget.state.defaultSemanticLabel,
      image: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: OrbPainter(
              timeline: _timeline,
              builder: _builder,
              source: _source,
              dark: widget.theme.resolveDark(context),
              colors: widget.colors,
            ),
          ),
        ),
      ),
    );
  }
}
