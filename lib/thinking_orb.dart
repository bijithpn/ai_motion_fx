/// Procedural, native-Flutter thinking orbs and AI-status effects.
///
/// Orbs: [ThinkingOrb], [ThinkingImageOrb], [ThinkingVoiceOrb] and
/// [ThinkingBorderBeam] (a port of the MIT-licensed `thinking-orbs` by
/// Jakub Antalik).
///
/// Glow effects that wrap your own widgets: [ThinkingVoiceGlow],
/// [ThinkingImageReveal] and [ThinkingBeam].
library;

export 'src/models/thinking_orb_state.dart' show ThinkingOrbShape, ThinkingOrbState, VoiceOrbState;
export 'src/theme/colors.dart' show ThinkingOrbColors;
export 'src/theme/glow_variant.dart' show ThinkingGlowVariant;
export 'src/theme/theme.dart' show ThinkingOrbTheme;
export 'src/widgets/thinking_beam.dart' show ThinkingBeam, ThinkingBeamSize;
export 'src/widgets/thinking_border_beam.dart' show ThinkingBorderBeam;
export 'src/widgets/thinking_image_orb.dart' show ThinkingImageOrb;
export 'src/widgets/thinking_image_reveal.dart'
    show ThinkingImageReveal, ThinkingImageRevealController, ThinkingRevealPreset;
export 'src/widgets/thinking_orb.dart' show ThinkingOrb;
export 'src/widgets/thinking_voice_glow.dart' show ThinkingVoiceGlow, ThinkingVoiceGlowType;
export 'src/widgets/thinking_voice_orb.dart' show ThinkingVoiceOrb;
