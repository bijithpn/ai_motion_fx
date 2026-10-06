import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../engine/glow_clock.dart';
import '../theme/theme.dart';

/// How the loader looks while the picture is being "generated".
enum ThinkingRevealPreset {
  /// A mosaic of soft squares that twinkle and shrink away at random.
  pixelsOrganic,

  /// Hard-edged blocks that tick over in steps and clear row by row.
  pixelsMechanic,

  /// A flowing colour wash wiped away by a soft diagonal edge.
  sweepGradient;

  /// Short name used in docs and demos, e.g. `pixels-organic`.
  String get label => switch (this) {
        ThinkingRevealPreset.pixelsOrganic => 'pixels-organic',
        ThinkingRevealPreset.pixelsMechanic => 'pixels-mechanic',
        ThinkingRevealPreset.sweepGradient => 'sweep-gradient',
      };
}

/// Lets you drive a [ThinkingImageReveal] from the outside.
///
/// ```dart
/// final reveal = ThinkingImageRevealController();
/// ThinkingImageReveal(controller: reveal, images: [...], autoReveal: false);
/// // later:
/// reveal.replay();
/// ```
class ThinkingImageRevealController {
  _ThinkingImageRevealState? _state;

  /// Covers the picture again, churns, and reveals it once more.
  void replay() => _state?._replay();

  /// Same as [replay] but moves on to the next image in the list first.
  void next() => _state?._next();

  /// Whether the current image is fully revealed.
  bool get isRevealed => _state?._isRevealed ?? false;
}

/// A loader that dissolves into a real image, the way a generated picture
/// appears: a churning mosaic (or colour wash) covers the frame, then clears
/// to show the picture underneath.
///
/// ```dart
/// ThinkingImageReveal(
///   images: [NetworkImage(a), NetworkImage(b)],
///   preset: ThinkingRevealPreset.pixelsOrganic,
///   width: 320,
///   height: 320,
///   borderRadius: BorderRadius.circular(20),
///   autoReveal: true,
/// )
/// ```
///
/// With `autoReveal` it loops on its own: the image sits for a moment, the
/// mosaic comes back over it, the next image is swapped in behind the cover,
/// and it clears again. Without it the loader keeps churning until you call
/// [ThinkingImageRevealController.replay], which makes it behave like a
/// "generating…" state you resolve when your real image is ready.
///
/// The mosaic is tinted with colours sampled from the picture itself, so it
/// feels related to what is about to appear instead of generic noise. It's
/// all plain canvas drawing, with no shaders or extra dependencies.
class ThinkingImageReveal extends StatefulWidget {
  /// Creates an image reveal.
  const ThinkingImageReveal({
    super.key,
    required this.images,
    this.preset = ThinkingRevealPreset.pixelsOrganic,
    this.autoReveal = true,
    this.controller,
    this.width,
    this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
    this.theme = ThinkingOrbTheme.auto,
    this.fit = BoxFit.cover,
    this.speed = 1,
    this.paused = false,
    this.onRevealed,
    this.semanticLabel,
    this.reducedMotion,
  });

  /// Pictures the loader resolves into. They're cycled when [autoReveal] is on.
  final List<ImageProvider> images;

  /// Visual style of the loader.
  final ThinkingRevealPreset preset;

  /// Loops generate → reveal → next image on its own.
  final bool autoReveal;

  /// Optional handle to replay the reveal from code.
  final ThinkingImageRevealController? controller;

  /// Width in logical pixels. When null the widget fills the available width
  /// (or 300 if that is unbounded).
  final double? width;

  /// Height in logical pixels. When null the widget fills the available
  /// height (or 300 if that is unbounded).
  final double? height;

  /// Corner radius of the frame.
  final BorderRadius borderRadius;

  /// Light or dark surface for the loader. `auto` follows the app theme.
  final ThinkingOrbTheme theme;

  /// How the picture fills the frame.
  final BoxFit fit;

  /// Speed multiplier for the whole cycle.
  final double speed;

  /// Freezes the animation on the current frame.
  final bool paused;

  /// Called each time an image finishes revealing.
  final VoidCallback? onRevealed;

  /// Accessibility label for the picture.
  final String? semanticLabel;

  /// Forces (true) or disables (false) the static reduced-motion view, which
  /// shows the finished picture with no loader. `null` follows the platform.
  final bool? reducedMotion;

  @override
  State<ThinkingImageReveal> createState() => _ThinkingImageRevealState();
}

/// Decoded picture plus a tiny colour grid used to tint the mosaic.
class _Loaded {
  _Loaded(this.image, this.grid);
  final ui.Image image;
  final Uint8List? grid; // grid × grid RGBA

  static const gridSize = 32;

  Color? at(double u, double v) {
    final g = grid;
    if (g == null) return null;
    final x = (u * gridSize).floor().clamp(0, gridSize - 1);
    final y = (v * gridSize).floor().clamp(0, gridSize - 1);
    final o = (y * gridSize + x) * 4;
    return Color.fromARGB(255, g[o], g[o + 1], g[o + 2]);
  }
}

class _ThinkingImageRevealState extends State<ThinkingImageReveal> with SingleTickerProviderStateMixin {
  // Seconds. The cover-in only plays when swapping from a shown picture.
  static const _coverIn = 0.85, _churn = 1.3, _resolve = 2.3, _hold = 2.6;
  static const _revealEnd = _coverIn + _churn + _resolve;
  static const _total = _revealEnd + _hold;

  late final GlowClock _clock = GlowClock(this, onFrame: _step);
  final Map<int, _Loaded> _loaded = {};
  final Set<int> _loading = {};
  double cycle = _coverIn; // first run skips the cover-in
  int index = 0;
  int _target = 0;
  bool _armed = true;
  bool _announced = false;
  bool _reduced = false;

  bool get _isRevealed => _armed && cycle >= _revealEnd && _loaded.containsKey(index);

  @override
  void initState() {
    super.initState();
    _armed = widget.autoReveal;
    widget.controller?._state = this;
    _load(0);
    if (widget.images.length > 1) _load(1);
  }

  // ── loading ──────────────────────────────────────────────────────────

  Future<void> _load(int i) async {
    if (i >= widget.images.length || _loaded.containsKey(i) || _loading.contains(i)) return;
    _loading.add(i);
    final done = Completer<ui.Image?>();
    final stream = widget.images[i].resolve(ImageConfiguration.empty);
    late ImageStreamListener listener;
    listener = ImageStreamListener(
      (info, _) {
        if (!done.isCompleted) done.complete(info.image.clone());
        stream.removeListener(listener);
      },
      onError: (_, _) {
        if (!done.isCompleted) done.complete(null);
        stream.removeListener(listener);
      },
    );
    stream.addListener(listener);
    final image = await done.future;
    _loading.remove(i);
    if (image == null) return;
    if (!mounted) {
      image.dispose();
      return;
    }
    Uint8List? grid;
    try {
      // Squash the picture to a 32×32 colour grid for tinting the mosaic.
      final recorder = ui.PictureRecorder();
      Canvas(recorder).drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, _Loaded.gridSize.toDouble(), _Loaded.gridSize.toDouble()),
        Paint()..filterQuality = FilterQuality.medium,
      );
      final small = await recorder.endRecording().toImage(_Loaded.gridSize, _Loaded.gridSize);
      final bytes = await small.toByteData(format: ui.ImageByteFormat.rawRgba);
      small.dispose();
      grid = bytes?.buffer.asUint8List();
    } catch (_) {
      grid = null; // tint is optional
    }
    if (!mounted) {
      image.dispose();
      return;
    }
    _loaded[i] = _Loaded(image, grid);
    _clock.poke();
  }

  // ── timeline ─────────────────────────────────────────────────────────

  void _step(double dt) {
    if (!_armed) return;
    // Swap the picture only while it is fully covered.
    if (cycle >= _coverIn && index != _target) {
      index = _target;
      _announced = false;
    }
    if (!_loaded.containsKey(index)) {
      _load(index);
      // Keep churning (never start the reveal) until the picture is decoded.
      if (cycle >= _coverIn + _churn) return;
    }
    cycle += dt;
    if (!_announced && cycle >= _revealEnd) {
      _announced = true;
      widget.onRevealed?.call();
    }
    if (cycle >= _total) {
      if (widget.autoReveal && widget.images.isNotEmpty) {
        cycle = 0;
        _target = (index + 1) % widget.images.length;
        _load(_target);
        _load((_target + 1) % widget.images.length);
      } else {
        cycle = _total;
      }
    }
  }

  void _replay() {
    _armed = true;
    _announced = false;
    _target = index;
    cycle = _loaded.containsKey(index) && _revealEnd <= cycle ? 0 : _coverIn;
    _clock.poke();
  }

  void _next() {
    if (widget.images.isEmpty) return;
    _armed = true;
    _announced = false;
    _target = (index + 1) % widget.images.length;
    _load(_target);
    cycle = 0;
    _clock.poke();
  }

  /// Reveal progress, 0 (fully covered) to 1 (picture fully shown).
  double get progress {
    if (!_armed || !_loaded.containsKey(index)) return 0;
    if (cycle < _coverIn) return 1 - Curves.easeInOutCubic.transform(cycle / _coverIn);
    if (cycle < _coverIn + _churn) return 0;
    return Curves.easeInOutCubic.transform(((cycle - _coverIn - _churn) / _resolve).clamp(0.0, 1.0));
  }

  // ── lifecycle ────────────────────────────────────────────────────────

  void _sync() {
    _reduced = resolveReducedMotion(context, widget.reducedMotion);
    _clock.speed = widget.speed;
    _clock.setRunning(!widget.paused && !_reduced);
    _clock.poke();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ThinkingImageReveal old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller?._state = null;
      widget.controller?._state = this;
    }
    if (!listEquals(old.images, widget.images)) {
      for (final l in _loaded.values) {
        l.image.dispose();
      }
      _loaded.clear();
      _loading.clear();
      index = 0;
      _target = 0;
      cycle = _coverIn;
      _announced = false;
      _load(0);
    }
    if (widget.autoReveal != old.autoReveal) {
      _armed = widget.autoReveal;
      if (_armed) {
        cycle = _coverIn;
      } else {
        cycle = _coverIn;
        _target = index;
      }
    }
    _sync();
  }

  @override
  void dispose() {
    widget.controller?._state = null;
    _clock.dispose();
    for (final l in _loaded.values) {
      l.image.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = widget.theme.resolveDark(context);
    Widget paint = CustomPaint(painter: _RevealPainter(this, dark), size: Size.infinite);
    paint = Semantics(
      image: true,
      label: widget.semanticLabel ?? 'Generated image',
      child: ExcludeSemantics(child: RepaintBoundary(child: paint)),
    );
    final w = widget.width, h = widget.height;
    if (w != null && h != null) return SizedBox(width: w, height: h, child: paint);
    return LayoutBuilder(
      builder: (context, c) => SizedBox(
        width: w ?? (c.maxWidth.isFinite ? c.maxWidth : 300),
        height: h ?? (c.maxHeight.isFinite ? c.maxHeight : 300),
        child: paint,
      ),
    );
  }
}

// ─────────────────────────── painting ───────────────────────────

double _hash(int a, int b, int c) {
  var x = a * 374761393 + b * 668265263 + c * 2147483647;
  x = (x ^ (x >> 13)) * 1274126177;
  x = x ^ (x >> 16);
  return (x & 0xFFFF) / 65535.0;
}

class _RevealPainter extends CustomPainter {
  _RevealPainter(this.s, this.dark) : super(repaint: s._clock);
  final _ThinkingImageRevealState s;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final wd = s.widget;
    final rect = Offset.zero & size;
    final loaded = s._loaded[s.index];
    final p = s._reduced ? 1.0 : s.progress;
    final t = s._clock.time;

    canvas.save();
    canvas.clipRRect(wd.borderRadius.toRRect(rect));
    canvas.drawRect(rect, Paint()..color = dark ? const Color(0xFF16161A) : const Color(0xFFE8E8EE));
    if (loaded != null) {
      paintImage(
        canvas: canvas,
        rect: rect,
        image: loaded.image,
        fit: wd.fit,
        filterQuality: FilterQuality.medium,
      );
    }

    // Colour of the real picture under a point (to tint the mosaic).
    Color? tint(double x, double y) {
      if (loaded == null) return null;
      final iw = loaded.image.width.toDouble(), ih = loaded.image.height.toDouble();
      final k = wd.fit == BoxFit.cover ? math.max(size.width / iw, size.height / ih) : math.min(size.width / iw, size.height / ih);
      final u = (x - (size.width - iw * k) / 2) / (iw * k);
      final v = (y - (size.height - ih * k) / 2) / (ih * k);
      return loaded.at(u.clamp(0.0, 1.0), v.clamp(0.0, 1.0));
    }

    if (p < 0.999) {
      switch (wd.preset) {
        case ThinkingRevealPreset.sweepGradient:
          _sweep(canvas, size, p, t, tint);
        case ThinkingRevealPreset.pixelsOrganic:
        case ThinkingRevealPreset.pixelsMechanic:
          _pixels(canvas, size, p, t, tint);
      }
    }
    canvas.restore();
  }

  void _pixels(Canvas canvas, Size size, double p, double t, Color? Function(double, double) tint) {
    final organic = s.widget.preset == ThinkingRevealPreset.pixelsOrganic;
    final cols = organic ? 28 : 18;
    final cell = size.width / cols;
    final rows = (size.height / cell).ceil();

    // Churn clock: organic cells glide between random values; mechanic ticks.
    final ft = t * (organic ? 6.0 : 4.0);
    final frame = ft.floor();
    final mix = organic ? Curves.easeInOut.transform(ft - frame) : 0.0;

    const span = 0.38; // how long each cell takes to clear, in progress units
    final paint = Paint();
    final lo = dark ? const Color(0xFF17171D) : const Color(0xFFDADAE3);
    final hi = dark ? const Color(0xFFEDEDF5) : const Color(0xFF2A2A34);
    final accent = const Color(0xFF38BDF8);

    for (var cy = 0; cy < rows; cy++) {
      for (var cx = 0; cx < cols; cx++) {
        final fixed = _hash(cx, cy, 7);
        final double th;
        if (organic) {
          final dx = cx / cols - 0.5, dy = cy / rows - 0.5;
          final dist = math.min(1.0, math.sqrt(dx * dx + dy * dy) * 1.5);
          th = 0.62 * fixed + 0.38 * dist;
        } else {
          th = 0.8 * ((cy * cols + cx) / (rows * cols)) + 0.2 * fixed;
        }
        final local = ((p * (1 + span) - th) / span).clamp(0.0, 1.0);
        final cover = 1 - Curves.easeInOutCubic.transform(local);
        if (cover <= 0.01) continue;

        final h0 = _hash(cx, cy, frame), h1 = _hash(cx, cy, frame + 1);
        final h = h0 + (h1 - h0) * mix;
        final Color base = organic
            ? Color.lerp(lo, hi, h)!
            : Color.lerp(lo, accent, (h * 4).floor() / 4 * 0.85)!;
        final img = tint((cx + 0.5) * cell, (cy + 0.5) * cell);
        final color = img == null ? base : Color.lerp(base, img, 0.5)!;

        if (organic) {
          // Squares shrink toward their centre as they clear.
          final side = (cell - 1) * math.sqrt(cover);
          final c = Offset((cx + 0.5) * cell, (cy + 0.5) * cell);
          paint.color = color;
          canvas.drawRRect(
            RRect.fromRectAndRadius(Rect.fromCenter(center: c, width: side, height: side), Radius.circular(side * 0.18)),
            paint,
          );
        } else {
          paint.color = color.withValues(alpha: cover > 0.5 ? 1 : cover * 2);
          canvas.drawRect(Rect.fromLTWH(cx * cell + 0.5, cy * cell + 0.5, cell - 1, cell - 1), paint);
        }
      }
    }

    if (!organic && p > 0.01 && p < 0.96) {
      // A thin scan line riding the clearing front.
      final y = size.height * p;
      canvas.drawRect(
        Rect.fromLTWH(0, y - 1, size.width, 2),
        Paint()
          ..shader = ui.Gradient.linear(Offset(0, y), Offset(size.width, y), [
            accent.withValues(alpha: 0),
            accent.withValues(alpha: 0.9),
            accent.withValues(alpha: 0),
          ], [0, 0.5, 1]),
      );
    }
  }

  void _sweep(Canvas canvas, Size size, double p, double t, Color? Function(double, double) tint) {
    final rect = Offset.zero & size;
    final avg = tint(size.width / 2, size.height / 2);
    final palette = <Color>[
      const Color(0xFF7C5CFF),
      const Color(0xFF22D3EE),
      const Color(0xFFEC4899),
      const Color(0xFFFFB86B),
      ?avg,
    ];
    final d = math.max(size.width, size.height);

    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = dark ? const Color(0xFF14141A) : const Color(0xFFF1F1F6));
    // Four drifting colour blobs make a flowing wash.
    for (var i = 0; i < palette.length; i++) {
      final a = t * (0.35 + i * 0.11) + i * 1.7;
      final c = Offset(
        size.width * (0.5 + 0.42 * math.sin(a)),
        size.height * (0.5 + 0.42 * math.cos(a * 0.83 + i)),
      );
      canvas.drawCircle(
        c,
        d * 0.62,
        Paint()
          ..shader = ui.Gradient.radial(c, d * 0.62, [
            palette[i].withValues(alpha: 0.95),
            palette[i].withValues(alpha: 0),
          ]),
      );
    }
    // Wipe away what the front has passed. The edge is a gradient whose end
    // points slide along the diagonal, so it can start fully off-canvas.
    final diag = Offset(size.width, size.height);
    Offset along(double u) => diag * u;
    final front = p * 1.4 - 0.2; // 0 → fully covered, 1 → fully clear
    canvas.drawRect(
      rect,
      Paint()
        ..blendMode = BlendMode.dstOut
        ..shader = ui.Gradient.linear(
            along(front - 0.22), along(front), const [Color(0xFF000000), Color(0x00000000)]),
    );
    canvas.restore();

    if (p > 0.01 && p < 0.99) {
      // A thin bright line riding the edge of the wipe.
      canvas.drawRect(
        rect,
        Paint()
          ..blendMode = BlendMode.plus
          ..shader = ui.Gradient.linear(
            along(front - 0.1),
            along(front + 0.02),
            const [Color(0x00FFFFFF), Color(0x4DFFFFFF), Color(0x00FFFFFF)],
            const [0, 0.82, 1],
          ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RevealPainter old) => old.dark != dark || old.s != s;
}
