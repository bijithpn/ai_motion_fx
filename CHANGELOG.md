## 0.2.0

New glow effects that wrap your own widgets:

- `ThinkingVoiceGlow`: a sound-reactive glow along the bottom edge of any
  widget, with a "processing" beam, three geometry presets (`standard`, `pill`,
  `mobile`) and an input chain (sensitivity, threshold, attack, release).
- `ThinkingBeam`: a comet of colour around a widget's border. Five sizes (`md`,
  `sm`, `line`, `pulseInner`, `pulseOutside`). It follows the real outline at an
  even speed.
- `ThinkingImageReveal`: a mosaic / colour-wash loader that clears to show a
  real image. Three presets, looping or controller-driven
  (`ThinkingImageRevealController`), `onRevealed` callback. The mosaic is tinted
  with colours sampled from the picture.
- `ThinkingGlowVariant`: eight shared colour sets (`colorful`, `mono`, `ocean`,
  `sunset`, `forest`, `candy`, `ice`, `gold`).

All of them respect reduced motion, pause with `paused`, and stop when their
route is hidden.

Also: rewritten README with screenshots, a new example app (one tab per widget,
bundled sample pictures), and screenshot / sample-art generators in `tool/`.

## 0.1.0

- Initial release: native Flutter port of `thinking-orbs` 0.3.1.
- `ThinkingOrb` with all nine states (working, searching, solving, listening,
  connecting, weaving, composing, breathing, shaping) and both hand-tuned sizes
  (20 / 64), verified against the original's golden vectors.
- `ThinkingImageOrb`, `ThinkingVoiceOrb`, `ThinkingBorderBeam`.
- Shared animation clock, `TickerMode`-aware pausing, reduced-motion static
  frame, semantics.
