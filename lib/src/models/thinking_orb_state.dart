/// The nine shipped Thinking Orb animations. Each is a hand-tuned
/// procedural animation, not a variation of a single spinner.
enum ThinkingOrbState {
  /// Particles on tilted orbits.
  working('Working…'),

  /// A scan meridian sweeps a dotted globe.
  searching('Searching…'),

  /// Bands scramble in quarter turns, then click back.
  solving('Solving…'),

  /// A waveform rolls through latitude rings.
  listening('Listening…'),

  /// A constellation wires itself, packets running the edges.
  connecting('Connecting…'),

  /// Three strands plait around the sphere.
  weaving('Weaving…'),

  /// An undulating multi-band sash.
  composing('Composing…'),

  /// A face-on ring slowly morphing.
  breathing('Thinking…'),

  /// A dotted outline morphs circle → triangle → square.
  shaping('Shaping…');

  const ThinkingOrbState(this.defaultSemanticLabel);

  /// Default accessibility label (matches the original library's labels).
  final String defaultSemanticLabel;
}

/// States of the voice orb.
enum VoiceOrbState {
  /// Resting, barely breathing.
  idle('Idle'),

  /// Taking input; [intensity] drives the amplitude.
  listening('Listening…'),

  /// Busy; a scan meridian sweeps the lattice.
  processing('Processing…'),

  /// Responding; [intensity] drives the amplitude with a syllable envelope.
  speaking('Speaking…');

  const VoiceOrbState(this.defaultSemanticLabel);

  /// Default accessibility label.
  final String defaultSemanticLabel;
}

/// Which outline the [ThinkingOrbState.shaping] animation shows.
///
/// [cycle] is the original behaviour (circle → triangle → square → circle,
/// morphing between them). The others hold one outline still, keeping the
/// dots' gentle pulse.
enum ThinkingOrbShape {
  /// Morph circle → triangle → square → circle (the original).
  cycle,

  /// Hold the circle.
  circle,

  /// Hold the triangle.
  triangle,

  /// Hold the square.
  square,
}
