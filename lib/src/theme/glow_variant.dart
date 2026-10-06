import 'dart:ui';

/// Colour sets shared by [ThinkingVoiceGlow] and [ThinkingBeam].
///
/// Every variant is a short loop of colours that the effects blend between,
/// so a variant can be any length. `mono` is the only one that changes with
/// the theme: pale on dark surfaces, charcoal on light ones, so it never
/// disappears into the background.
enum ThinkingGlowVariant {
  /// A full-spectrum sweep: pink, amber, lime, cyan, indigo, violet.
  colorful,

  /// Neutral greys. Light ink on dark surfaces, dark ink on light ones.
  mono,

  /// Cool blues and teals.
  ocean,

  /// Warm coral, orange and magenta.
  sunset,

  /// Greens from emerald to lime.
  forest,

  /// Soft pastels: pink, lilac, aqua, butter.
  candy,

  /// Very pale blues. Best on dark surfaces.
  ice,

  /// Amber and gold.
  gold;

  /// The colour loop for this variant.
  List<Color> colors({required bool dark}) => switch (this) {
        ThinkingGlowVariant.colorful => const [
            Color(0xFFFF4D8D),
            Color(0xFFFF9A3D),
            Color(0xFFFFD84D),
            Color(0xFF4ADE80),
            Color(0xFF22D3EE),
            Color(0xFF6366F1),
            Color(0xFFC084FC),
          ],
        ThinkingGlowVariant.mono => dark
            ? const [Color(0xFF8B93A1), Color(0xFFFFFFFF), Color(0xFFB4BAC4)]
            : const [Color(0xFF111827), Color(0xFF6B7280), Color(0xFF1F2937)],
        ThinkingGlowVariant.ocean => const [
            Color(0xFF0EA5E9),
            Color(0xFF22D3EE),
            Color(0xFF2DD4BF),
            Color(0xFF3B82F6),
            Color(0xFF6366F1),
          ],
        ThinkingGlowVariant.sunset => const [
            Color(0xFFFF5F6D),
            Color(0xFFFF8A4C),
            Color(0xFFFFC371),
            Color(0xFFF43F8E),
            Color(0xFFB83280),
          ],
        ThinkingGlowVariant.forest => const [
            Color(0xFF10B981),
            Color(0xFF34D399),
            Color(0xFF84CC16),
            Color(0xFF14B8A6),
          ],
        ThinkingGlowVariant.candy => const [
            Color(0xFFF472B6),
            Color(0xFFC4B5FD),
            Color(0xFF67E8F9),
            Color(0xFFFDE68A),
          ],
        ThinkingGlowVariant.ice => const [
            Color(0xFFBAE6FD),
            Color(0xFFE0F2FE),
            Color(0xFFA5F3FC),
            Color(0xFFC7D2FE),
          ],
        ThinkingGlowVariant.gold => const [
            Color(0xFFFBBF24),
            Color(0xFFF59E0B),
            Color(0xFFFDE68A),
            Color(0xFFEA580C),
          ],
      };
}

/// Blends around a colour loop: [u] is 0…1 and wraps, so `u = 1` is `u = 0`.
Color sampleLoop(List<Color> colors, double u) {
  final n = colors.length;
  if (n == 1) return colors.first;
  final x = (u - u.floorToDouble()) * n;
  final i = x.floor() % n;
  return Color.lerp(colors[i], colors[(i + 1) % n], x - x.floorToDouble())!;
}
