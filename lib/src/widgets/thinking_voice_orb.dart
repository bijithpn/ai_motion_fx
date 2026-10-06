import 'package:flutter/widgets.dart';

import '../engine/animation_clock.dart';
import '../engine/orb_renderer.dart';
import '../engine/particle_system.dart';
import '../models/thinking_orb_config.dart';
import '../models/thinking_orb_state.dart';
import '../states/voice.dart';
import '../theme/colors.dart';
import '../theme/theme.dart';
import 'thinking_orb.dart' show kReducedMotionTime;

/// A voice / conversation orb in the Thinking Orb family.
///
/// Driven entirely by the [state] and [intensity] you supply — no microphone
/// or audio dependency. It is the `listening` wave lattice with its amplitude
/// and tempo following a smoothed energy, so level changes glide naturally:
/// [intensity] (0…1) is the live level while [VoiceOrbState.listening] or
/// [VoiceOrbState.speaking]; [VoiceOrbState.processing] sweeps a scan
/// meridian across the lattice; [VoiceOrbState.idle] barely breathes.
class ThinkingVoiceOrb extends StatefulWidget {
  /// Creates a voice orb.
  const ThinkingVoiceOrb({
    super.key,
    this.state = VoiceOrbState.idle,
    this.intensity = 0,
    this.size = 64,
    this.theme = ThinkingOrbTheme.auto,
    this.speed = 1.0,
    this.paused = false,
    this.semanticLabel,
    this.colors = ThinkingOrbColors.standard,
    this.reducedMotion,
  });

  /// Current voice state.
  final VoiceOrbState state;

  /// Live level in 0…1 (clamped).
  final double intensity;

  /// Side length in logical pixels.
  final double size;

  /// Light/dark ink.
  final ThinkingOrbTheme theme;

  /// Speed multiplier.
  final double speed;

  /// Freezes the animation on the current frame.
  final bool paused;

  /// Accessibility label (defaults to the state's label).
  final String? semanticLabel;

  /// Ink palette.
  final ThinkingOrbColors colors;

  /// Forces / disables the reduced-motion static frame; null follows the platform.
  final bool? reducedMotion;

  @override
  State<ThinkingVoiceOrb> createState() => _ThinkingVoiceOrbState();
}

class _ThinkingVoiceOrbState extends State<ThinkingVoiceOrb> with SingleTickerProviderStateMixin {
  late final OrbTimeline _timeline = OrbTimeline(this);
  final FrameBuilder _builder = FrameBuilder();
  late VoiceFrameSource _source;

  ResolvedOrbConfig _config() =>
      ResolvedOrbConfig.resolve(ThinkingOrbState.listening, OrbTuning.forSize(widget.size));

  @override
  void initState() {
    super.initState();
    _source = VoiceFrameSource(_config());
    _push();
  }

  void _push() {
    _source
      ..state = widget.state
      ..intensity = widget.intensity;
  }

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
  void didUpdateWidget(ThinkingVoiceOrb old) {
    super.didUpdateWidget(old);
    final cfg = _config();
    if (!identical(cfg, _source.config)) _source = VoiceFrameSource(cfg);
    _push();
    _sync();
    // With frozen time there are no frames to ease across: jump to the target.
    if (!_timeline.isRunning) _source.snap = true;
    // State/intensity live in the source, so repaint even when time is frozen.
    _builder.builtSource = null;
    _timeline.repaint();
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
