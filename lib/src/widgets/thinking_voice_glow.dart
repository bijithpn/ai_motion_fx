import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../engine/glow_clock.dart';
import '../theme/glow_variant.dart';
import '../theme/theme.dart';
import 'thinking_orb.dart' show kReducedMotionTime;

/// Rough size class of the element the glow sits on. It sets how tall the
/// glow rises and how wide each lobe spreads, so the same effect feels right
/// on a chat box, a small recording pill, and the bottom of a phone screen.
enum ThinkingVoiceGlowType {
  /// A chat input around 350 px wide.
  standard,

  /// A compact recording pill, roughly 150 × 44.
  pill,

  /// The bottom edge of a phone screen: taller, wider glow.
  mobile,
}

/// A sound-reactive glow along the bottom edge of any widget.
///
/// A row of coloured lobes sits on the child's lower border. They rise and
/// bloom as [level] goes up and settle back when it drops, and a soft halo
/// spills just past the edge. While [processing] is true the lobes gather
/// into one bright beam that sweeps back and forth, which reads well as
/// "working on it" between the user speaking and the reply starting.
///
/// ```dart
/// ThinkingVoiceGlow(
///   level: micLevel,            // 0…1, from whatever meters your audio
///   processing: waitingForReply,
///   borderRadius: BorderRadius.circular(28),
///   child: ChatInput(),
/// )
/// ```
///
/// The package never touches the microphone. Feed [level] from your own
/// recorder or from a stream of amplitudes; it is smoothed internally (fast
/// attack, slower release), so noisy values are fine.
class ThinkingVoiceGlow extends StatefulWidget {
  /// Creates a voice glow around [child].
  const ThinkingVoiceGlow({
    super.key,
    required this.child,
    this.type = ThinkingVoiceGlowType.standard,
    this.level = 0,
    this.processing = false,
    this.colorVariant = ThinkingGlowVariant.colorful,
    this.colors,
    this.borderRadius = const BorderRadius.all(Radius.circular(28)),
    this.theme = ThinkingOrbTheme.auto,
    this.strength = 1,
    this.sensitivity = 1,
    this.threshold = 0.04,
    this.attack = 0.06,
    this.release = 0.35,
    this.reach = 1,
    this.spread = 1,
    this.flow = 1,
    this.idle = 0.12,
    this.speed = 1,
    this.paused = false,
    this.reducedMotion,
  });

  /// The widget the glow is drawn on. The glow never intercepts touches.
  final Widget child;

  /// Geometry preset, see [ThinkingVoiceGlowType].
  final ThinkingVoiceGlowType type;

  /// Live input level from 0 (silence) to 1 (loud).
  final double level;

  /// Gathers the glow into a travelling beam while work is in progress.
  final bool processing;

  /// Named colour set. Ignored when [colors] is given.
  final ThinkingGlowVariant colorVariant;

  /// Your own colours (any number, 2–7 looks best). Overrides [colorVariant].
  final List<Color>? colors;

  /// Corner radius of the child. Match it so the glow hugs the border.
  final BorderRadius borderRadius;

  /// Light or dark surface. `auto` follows the app theme.
  final ThinkingOrbTheme theme;

  /// Overall opacity of the effect, 0–1.
  final double strength;

  /// Input gain applied to [level] before the noise gate.
  final double sensitivity;

  /// Noise gate: levels below this count as silence.
  final double threshold;

  /// Seconds the glow takes to rise to a louder level.
  final double attack;

  /// Seconds the glow takes to fall back after a loud moment.
  final double release;

  /// How far the glow rises, as a multiplier of the preset height.
  final double reach;

  /// How wide each lobe spreads, as a multiplier of the preset width.
  final double spread;

  /// How fast the lobes drift sideways and pulse.
  final double flow;

  /// How much the glow breathes at silence, 0 for none.
  final double idle;

  /// Speed multiplier for all motion.
  final double speed;

  /// Freezes the animation on the current frame.
  final bool paused;

  /// Forces (true) or disables (false) the static reduced-motion frame.
  /// `null` follows the platform accessibility setting.
  final bool? reducedMotion;

  @override
  State<ThinkingVoiceGlow> createState() => _ThinkingVoiceGlowState();
}

class _ThinkingVoiceGlowState extends State<ThinkingVoiceGlow> with SingleTickerProviderStateMixin {
  late final GlowClock _clock = GlowClock(this, onFrame: _step);
  double _env = 0; // smoothed, gated level
  double _proc = 0; // smoothed processing weight
  bool _reduced = false;

  double get env => _env;
  double get proc => _proc;

  void _step(double dt) {
    final w = widget;
    var x = (w.level * w.sensitivity - w.threshold) / (1 - w.threshold).clamp(0.01, 1.0);
    x = x.clamp(0.0, 1.0);
    final tau = math.max(x > _env ? w.attack : w.release, 0.001);
    _env += (x - _env) * (1 - math.exp(-dt / tau));
    _proc += ((w.processing ? 1.0 : 0.0) - _proc) * (1 - math.exp(-dt / 0.3));
  }

  void _sync() {
    _reduced = resolveReducedMotion(context, widget.reducedMotion);
    _clock.speed = widget.speed;
    if (_reduced) {
      // One representative frame, like the orbs: a gentle, mid-level glow.
      _clock.time = kReducedMotionTime;
      _env = (widget.level * widget.sensitivity).clamp(0.0, 1.0);
      _proc = widget.processing ? 1 : 0;
    }
    _clock.setRunning(!widget.paused && !_reduced);
    _clock.poke();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ThinkingVoiceGlow old) {
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
              child: CustomPaint(
                painter: _VoiceGlowPainter(this, colors, dark),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VoiceGlowPainter extends CustomPainter {
  _VoiceGlowPainter(this.s, this.colors, this.dark) : super(repaint: s._clock);

  final _ThinkingVoiceGlowState s;
  final List<Color> colors;
  final bool dark;

  static const _stops = [0.0, 0.22, 0.48, 0.74, 1.0];
  static const _falloff = [1.0, 0.62, 0.3, 0.1, 0.0];

  /// A soft elliptical blob centred on (cx, cy). Falls off like a gaussian.
  void _blob(Canvas canvas, Paint paint, double cx, double cy, double rx, double ry, Color c, double alpha) {
    if (alpha < 0.004 || rx < 0.5 || ry < 0.5) return;
    canvas.save();
    canvas.translate(cx, cy);
    canvas.scale(rx, ry);
    paint.shader = ui.Gradient.radial(
      Offset.zero,
      1,
      [for (final f in _falloff) c.withValues(alpha: (alpha * f).clamp(0.0, 1.0))],
      _stops,
    );
    canvas.drawCircle(Offset.zero, 1, paint);
    canvas.restore();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    if (w <= 0 || h <= 0) return;
    final wd = s.widget;
    final t = s._clock.time * wd.flow;
    final proc = s.proc;
    final a = wd.strength.clamp(0.0, 1.0);
    final n = colors.length;

    // How high and how wide, by preset.
    final (baseRise, lobeWidth) = switch (wd.type) {
      ThinkingVoiceGlowType.standard => (54.0, 1.15),
      ThinkingVoiceGlowType.pill => (36.0, 0.95),
      ThinkingVoiceGlowType.mobile => (120.0, 1.45),
    };
    final rise = math.min(h * 0.95, baseRise * wd.reach);

    // Breathing floor so it never looks switched off.
    final breathe = wd.idle * (0.55 + 0.45 * math.sin(t * 1.3));
    final energy = (breathe + (1 - wd.idle) * s.env).clamp(0.0, 1.0);

    final paint = Paint()..blendMode = dark ? BlendMode.plus : BlendMode.srcOver;
    final rrect = wd.borderRadius.toRRect(Offset.zero & size);

    // ── Lobes, inside the child's shape ──
    canvas.save();
    canvas.clipRRect(rrect);
    for (var i = 0; i < n; i++) {
      final f = (i + 0.5) / n;
      final drift = 0.045 * math.sin(t * 0.8 + i * 1.7) + 0.02 * math.sin(t * 1.9 + i * 0.6);
      final cx = w * (f + drift);
      final pulse = 0.6 + 0.4 * math.sin(t * (1.7 + i * 0.31) + i * 2.1);
      final bell = 0.5 + 0.5 * math.cos((f - 0.5) * math.pi * 1.1);
      final ry = rise * (0.2 + 0.95 * energy * pulse * (0.55 + 0.45 * bell)) * (1 - proc * 0.92);
      final rx = (w / n) * lobeWidth * wd.spread * (1 + 0.45 * energy);
      _blob(canvas, paint, cx, h, rx, ry, colors[i], 0.9 * a * (1 - proc));
    }

    // ── Processing beam, with a short comet trail ──
    if (proc > 0.01) {
      for (var k = 5; k >= 0; k--) {
        final tt = t - k * 0.07;
        final x = w * (0.08 + 0.84 * (0.5 - 0.5 * math.cos(tt * 1.25)));
        final c = sampleLoop(colors, tt * 0.22);
        final fade = math.pow(1 - k / 6, 1.6).toDouble();
        _blob(canvas, paint, x, h, w * 0.17, rise * 0.62, c, 0.95 * a * proc * fade);
        if (k == 0) {
          _blob(canvas, paint, x, h, w * 0.06, rise * 0.34, const Color(0xFFFFFFFF), 0.8 * a * proc);
        }
      }
    }

    // ── Bright hairline hugging the bottom border ──
    final lineAlpha = ((0.3 + 0.7 * energy) * a * (1 - proc * 0.4)).clamp(0.0, 1.0);
    canvas.drawRect(
      Rect.fromLTWH(0, h - 1.5, w, 1.5),
      Paint()
        ..shader = ui.Gradient.linear(Offset.zero, Offset(w, 0), [
          for (var i = 0; i <= n; i++) colors[i % n].withValues(alpha: lineAlpha),
        ], [
          for (var i = 0; i <= n; i++) i / n,
        ]),
    );
    canvas.restore();

    // ── Halo spilling just below the edge ──
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(-rise, h, w + rise, h + rise * 0.6));
    final spill = (0.25 + 0.75 * energy) * a * 0.55;
    for (var i = 0; i < n; i++) {
      final f = (i + 0.5) / n;
      final cx = w * (f + 0.045 * math.sin(t * 0.8 + i * 1.7));
      final rx = (w / n) * lobeWidth * wd.spread * 1.1;
      _blob(canvas, paint, cx, h, rx, rise * 0.34 * (0.5 + energy), colors[i], spill * (1 - proc * 0.6));
    }
    if (proc > 0.01) {
      final x = w * (0.08 + 0.84 * (0.5 - 0.5 * math.cos(t * 1.25)));
      _blob(canvas, paint, x, h, w * 0.16, rise * 0.3, sampleLoop(colors, t * 0.22), 0.7 * a * proc);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VoiceGlowPainter old) =>
      old.colors != colors || old.dark != dark || old.s != s;
}
