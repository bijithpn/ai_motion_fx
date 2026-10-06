import 'package:flutter/widgets.dart';

import '../engine/animation_clock.dart';
import '../engine/orb_renderer.dart';
import '../engine/particle_system.dart';
import '../models/thinking_orb_config.dart';
import '../models/thinking_orb_state.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import 'thinking_orb.dart' show kReducedMotionTime;

/// A circular image seated *inside* a Thinking Orb.
///
/// The orb's geometry is split at its depth midplane: the far half of the dots
/// is painted behind the image, the near half in front, so the marks appear to
/// orbit the picture rather than sit beside it. The image itself is an
/// ordinary Flutter [Image], decoded and cached by the framework — nothing is
/// decoded during animation, and it can be swapped without touching the engine.
class ThinkingImageOrb extends StatefulWidget {
  /// Creates an image orb.
  const ThinkingImageOrb({
    super.key,
    this.image,
    this.placeholder,
    this.size = 64,
    this.state = ThinkingOrbState.working,
    this.shape = ThinkingOrbShape.cycle,
    this.theme = ThinkingOrbTheme.auto,
    this.speed = 1.0,
    this.paused = false,
    this.animate = true,
    this.imageScale = 0.56,
    this.showBorder = true,
    this.borderWidth = 1,
    this.borderColor,
    this.semanticLabel,
    this.colors = ThinkingOrbColors.standard,
    this.reducedMotion,
  });

  /// The picture. When null (or still loading / failed) [placeholder] shows.
  final ImageProvider? image;

  /// Shown while there is no image. Defaults to a soft ink-toned disc.
  final Widget? placeholder;

  /// Side length of the whole orb in logical pixels.
  final double size;

  /// Orb animation.
  final ThinkingOrbState state;

  /// Outline for [ThinkingOrbState.shaping]: the original morphing cycle, or
  /// one held shape. Ignored by other states.
  final ThinkingOrbShape shape;

  /// Light/dark ink.
  final ThinkingOrbTheme theme;

  /// Speed multiplier.
  final double speed;

  /// Freezes the orb on the current frame.
  final bool paused;

  /// When false the orb is a static frame around the image.
  final bool animate;

  /// Image diameter as a fraction of [size].
  final double imageScale;

  /// Draws a hairline ring around the image.
  final bool showBorder;

  /// Ring width.
  final double borderWidth;

  /// Ring colour; defaults to the theme's ink.
  final Color? borderColor;

  /// Accessibility label (defaults to the state's label).
  final String? semanticLabel;

  /// Ink palette.
  final ThinkingOrbColors colors;

  /// Forces / disables the reduced-motion static frame; null follows the platform.
  final bool? reducedMotion;

  @override
  State<ThinkingImageOrb> createState() => _ThinkingImageOrbState();
}

class _ThinkingImageOrbState extends State<ThinkingImageOrb> with SingleTickerProviderStateMixin {
  late final OrbTimeline _timeline = OrbTimeline(this);
  final FrameBuilder _builder = FrameBuilder();
  late PresetFrameSource _source;

  ResolvedOrbConfig _config() =>
      ResolvedOrbConfig.resolve(widget.state, OrbTuning.forSize(widget.size));

  @override
  void initState() {
    super.initState();
    _source = PresetFrameSource(_config(), shape: widget.shape);
  }

  void _sync() {
    final reduced = !widget.animate || resolveReducedMotion(context, widget.reducedMotion);
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
  void didUpdateWidget(ThinkingImageOrb old) {
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

  Widget _fallback(bool dark) =>
      widget.placeholder ??
      DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.colors.ink(0.78, dark: dark, alpha: 0.35),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final dark = widget.theme.resolveDark(context);
    final diameter = widget.size * widget.imageScale;

    OrbPainter painter(OrbLayer layer) => OrbPainter(
          timeline: _timeline,
          builder: _builder,
          source: _source,
          dark: dark,
          colors: widget.colors,
          layer: layer,
        );

    final image = widget.image;
    final disc = ClipOval(
      child: SizedBox.square(
        dimension: diameter,
        child: image == null
            ? _fallback(dark)
            : Image(
                image: image,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                frameBuilder: (context, child, frame, sync) =>
                    sync || frame != null ? child : _fallback(dark),
                errorBuilder: (context, error, stack) => _fallback(dark),
              ),
      ),
    );

    return Semantics(
      label: widget.semanticLabel ?? widget.state.defaultSemanticLabel,
      image: true,
      child: ExcludeSemantics(
        child: RepaintBoundary(
          child: SizedBox.square(
            dimension: widget.size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned.fill(child: CustomPaint(painter: painter(OrbLayer.back))),
                DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: widget.showBorder
                        ? Border.all(
                            width: widget.borderWidth,
                            color: widget.borderColor ??
                                widget.colors.ink(0.1, dark: dark, alpha: 0.55),
                          )
                        : null,
                  ),
                  child: disc,
                ),
                Positioned.fill(child: CustomPaint(painter: painter(OrbLayer.front))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
