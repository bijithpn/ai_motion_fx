import 'dart:ui';

import 'package:flutter/foundation.dart' show immutable;

/// Every colour the orb family renders with.
///
/// The original library is strictly monochrome: each mark carries an "ink
/// value" `white` in 0…1 (0 = darkest ink). On light substrates grey =
/// `white`; on dark substrates it is mirrored (`1 - white`) so near dots read
/// bright. [darkestInk] and [lightestInk] are the two ends of that ramp; the
/// defaults (black → white) reproduce the original exactly.
@immutable
class ThinkingOrbColors {
  /// Creates a palette.
  const ThinkingOrbColors({
    this.darkestInk = const Color(0xFF000000),
    this.lightestInk = const Color(0xFFFFFFFF),
  });

  /// Ink at `white == 0`.
  final Color darkestInk;

  /// Ink at `white == 1`.
  final Color lightestInk;

  /// The original library's pure greyscale ramp.
  static const ThinkingOrbColors standard = ThinkingOrbColors();

  /// Ink for a mark of ink value [white] (clamped to 0…1) with [alpha].
  Color ink(double white, {required bool dark, double alpha = 1}) {
    final w = white.clamp(0.0, 1.0);
    final g = ((dark ? 1 - w : w) * 255 + 0.5).floor();
    return _at(g, (alpha * 255 + 0.5).floor());
  }

  Color _at(int g, int a) {
    int ch(int lo, int hi) => (lo + (hi - lo) * g / 255 + 0.5).floor();
    return Color.fromARGB(
      a.clamp(0, 255),
      ch((darkestInk.r * 255).round(), (lightestInk.r * 255).round()),
      ch((darkestInk.g * 255).round(), (lightestInk.g * 255).round()),
      ch((darkestInk.b * 255).round(), (lightestInk.b * 255).round()),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ThinkingOrbColors &&
      other.darkestInk == darkestInk &&
      other.lightestInk == lightestInk;

  @override
  int get hashCode => Object.hash(darkestInk, lightestInk);
}

/// A lookup table of resolved [Color]s for the per-frame paint loop, so
/// steady-state painting allocates no colours. Shared per (colors, dark).
class InkPalette {
  InkPalette._(this._colors, this._dark);

  final ThinkingOrbColors _colors;
  final bool _dark;
  final List<Color?> _lut = List<Color?>.filled(256 * 256, null);

  static final Map<(ThinkingOrbColors, bool), InkPalette> _shared = {};

  /// The shared palette for [colors] on a dark/light substrate.
  factory InkPalette.of(ThinkingOrbColors colors, bool dark) =>
      _shared.putIfAbsent((colors, dark), () => InkPalette._(colors, dark));

  /// Colour for ink value [white] and [alpha] (both 0…1).
  Color at(double white, double alpha) {
    final w = white < 0 ? 0.0 : (white > 1 ? 1.0 : white);
    final g = ((_dark ? 1 - w : w) * 255 + 0.5).floor();
    final a = (alpha * 255 + 0.5).floor().clamp(0, 255);
    final i = g * 256 + a;
    return _lut[i] ??= _colors._at(g, a);
  }
}
