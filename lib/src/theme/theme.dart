import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Theme;

/// Theme mode for the orb family.
///
/// `dark` renders light ink (for dark backgrounds); `light` renders dark ink
/// (for light backgrounds). `auto` follows [Theme.of]'s brightness and
/// updates live when the app theme changes.
enum ThinkingOrbTheme {
  /// Follow `Theme.of(context).brightness`.
  auto,

  /// Dark ink on a light background.
  light,

  /// Light ink on a dark background.
  dark;

  /// Whether this resolves to the dark substrate in [context].
  bool resolveDark(BuildContext context) => switch (this) {
        ThinkingOrbTheme.dark => true,
        ThinkingOrbTheme.light => false,
        ThinkingOrbTheme.auto => Theme.of(context).brightness == Brightness.dark,
      };
}

/// Whether platform accessibility settings ask for reduced motion.
///
/// [override] wins when non-null (handy for demos and tests).
bool resolveReducedMotion(BuildContext context, bool? override) =>
    override ?? MediaQuery.maybeDisableAnimationsOf(context) ?? false;
