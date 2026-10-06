import 'dart:math' as math;

import 'thinking_orb_state.dart';

/// Per-mode numeric options. Mirrors the original `ModeOpts` bag; absent keys
/// fall back to per-mode defaults inside each state's frame function.
typedef ModeOpts = Map<String, double>;

/// Reads [key] or returns [fallback].
extension ModeOptsRead on ModeOpts {
  /// Value for [key], or [fallback] when the preset doesn't define it.
  double g(String key, double fallback) => this[key] ?? fallback;
}

/// The geometry builder behind each [ThinkingOrbState].
enum OrbMode { orbits, globe, rubik, wave, web, braid, ribbon, ring, morph }

/// State → geometry mode.
const Map<ThinkingOrbState, OrbMode> stateToMode = {
  ThinkingOrbState.working: OrbMode.orbits,
  ThinkingOrbState.searching: OrbMode.globe,
  ThinkingOrbState.solving: OrbMode.rubik,
  ThinkingOrbState.listening: OrbMode.wave,
  ThinkingOrbState.connecting: OrbMode.web,
  ThinkingOrbState.weaving: OrbMode.braid,
  ThinkingOrbState.composing: OrbMode.ribbon,
  ThinkingOrbState.breathing: OrbMode.ring,
  ThinkingOrbState.shaping: OrbMode.morph,
};

/// The two hand-tuned designs. They are separate tunings, not a scale factor.
enum OrbTuning {
  /// Inline-text scale (20 logical px).
  compact(20),

  /// Chat-avatar scale (64 logical px).
  standard(64);

  const OrbTuning(this.designSize);

  /// The size this tuning was designed for.
  final double designSize;

  /// Picks the tuning closest to [size] (on a log scale, so the split sits at
  /// ≈35.8px, the geometric mean of 20 and 64).
  static OrbTuning forSize(double size) =>
      size < math.sqrt(20 * 64) ? OrbTuning.compact : OrbTuning.standard;
}

/// A baked tuning for one (mode × size): multipliers over the base profile.
class ThinkingOrbPreset {
  /// Creates a preset.
  const ThinkingOrbPreset({
    required this.speed,
    required this.count,
    required this.size,
    this.extra = const {},
  });

  /// Multiplier on the shared clock.
  final double speed;

  /// Dot-count multiplier (2-D lattices scale each side by √count).
  final double count;

  /// Dot-radius multiplier.
  final double size;

  /// Mode options merged verbatim after scaling.
  final ModeOpts extra;
}

/// The shipped tunings, copied verbatim from the original `presets.ts`.
const Map<OrbMode, Map<OrbTuning, ThinkingOrbPreset>> orbPresets = {
  OrbMode.orbits: {
    OrbTuning.standard: ThinkingOrbPreset(speed: 1.885, count: 1, size: 1),
    OrbTuning.compact: ThinkingOrbPreset(speed: 3.9, count: 0.238, size: 2.4),
  },
  OrbMode.globe: {
    OrbTuning.standard: ThinkingOrbPreset(
        speed: 2.015, count: 0.42, size: 1.15, extra: {'scanMul': 4.08, 'dimBase': 0.45}),
    OrbTuning.compact: ThinkingOrbPreset(
        speed: 2.665, count: 0.105, size: 1.75, extra: {'scanMul': 4.335, 'dimBase': 0.45}),
  },
  OrbMode.rubik: {
    OrbTuning.standard: ThinkingOrbPreset(speed: 1.82, count: 0.35, size: 1.05),
    OrbTuning.compact: ThinkingOrbPreset(speed: 1.95, count: 0.088, size: 1.9),
  },
  OrbMode.wave: {
    OrbTuning.standard: ThinkingOrbPreset(speed: 4.388, count: 0.341, size: 1),
    OrbTuning.compact: ThinkingOrbPreset(speed: 3.998, count: 0.105, size: 1.6),
  },
  OrbMode.web: {
    OrbTuning.standard: ThinkingOrbPreset(speed: 3.315, count: 1.35, size: 0.95),
    OrbTuning.compact: ThinkingOrbPreset(speed: 6.63, count: 0.25, size: 1.52),
  },
  OrbMode.braid: {
    OrbTuning.standard: ThinkingOrbPreset(speed: 1.625, count: 0.5, size: 1),
    OrbTuning.compact: ThinkingOrbPreset(speed: 2.75, count: 0.1125, size: 1.36),
  },
  OrbMode.ribbon: {
    OrbTuning.standard: ThinkingOrbPreset(
        speed: 2.34, count: 0.25, size: 0.85, extra: {'spin': 0, 'bandMul': 3.9, 'wobMul': 1}),
    OrbTuning.compact: ThinkingOrbPreset(
        speed: 3.12, count: 0.051, size: 1.073, extra: {'spin': 0, 'bandMul': 4.94, 'wobMul': 1}),
  },
  OrbMode.ring: {
    OrbTuning.standard: ThinkingOrbPreset(
        speed: 3.24, count: 0.25, size: 0.956, extra: {'spin': 0, 'bandMul': 3.627, 'wobMul': 0.368}),
    OrbTuning.compact: ThinkingOrbPreset(
        speed: 3.78, count: 0.028, size: 1.622, extra: {'spin': 0, 'bandMul': 3.968, 'wobMul': 0.565}),
  },
  OrbMode.morph: {
    OrbTuning.standard: ThinkingOrbPreset(
        speed: 2.405, count: 0.702, size: 0.395, extra: {'spread': 1.45}),
    OrbTuning.compact: ThinkingOrbPreset(
        speed: 2.08, count: 0.53, size: 1.011, extra: {'spread': 1.45}),
  },
};

/// Base ("fine") density profiles per mode, before preset multipliers.
const Map<OrbMode, ModeOpts> baseProfiles = {
  OrbMode.globe: {
    'latRings': 17, 'lonDensity': 44, 'rBase': 0.6, 'rDepth': 1.7, 'rBoost': 1.0,
    'inkFar': 0.62, 'inkSpan': 0.54, 'rsPow': 0.6, 'rMin': 0.3,
  },
  OrbMode.orbits: {
    'orbitN': 12, 'ghostN': 40, 'ghostR': 0.9, 'ghostA': 0.5, 'particles': 3,
    'partR': 1.2, 'partRDepth': 1.6, 'rsPow': 0.6, 'rMin': 0.3,
  },
  OrbMode.rubik: {
    'latRings': 15, 'lonDensity': 40, 'moveCount': 14, 'rBase': 0.6, 'rDepth': 1.7,
    'rActive': 0.3, 'inkFar': 0.62, 'inkSpan': 0.54, 'rsPow': 0.6, 'rMin': 0.3,
  },
  OrbMode.wave: {
    'rings': 15, 'lonDensity': 40, 'rBase': 0.6, 'rDepth': 1.7, 'rsPow': 0.6, 'rMin': 0.3,
  },
  OrbMode.web: {
    'nodeN': 30, 'thr': 0.72, 'signals': 5, 'nodeR': 1.4, 'nodeRDepth': 1.8,
    'lineW': 0.8, 'rsPow': 0.6, 'rMin': 0.3,
  },
  OrbMode.braid: {
    'strandN': 52, 'turns': 3.0, 'ghostN': 150, 'rBase': 1.2, 'rDepth': 1.8,
    'rsPow': 0.6, 'rMin': 0.3,
  },
  OrbMode.ribbon: {
    'lanes': 5, 'segs': 88, 'ghostN': 150, 'rBase': 1.1, 'rDepth': 1.7,
    'rsPow': 0.6, 'rMin': 0.3,
  },
  OrbMode.ring: {
    'lanes': 5, 'segs': 88, 'ghostN': 0, 'faceOn': 1, 'rBase': 1.1, 'rDepth': 1.7,
    'rsPow': 0.6, 'rMin': 0.3,
  },
  OrbMode.morph: {'rDot': 0.021, 'iconD': 1, 'rMin': 0.25},
};

// 2-D lattices come in pairs: each side takes √scale so the TOTAL dot count
// scales by `scale`; flat lists scale linearly.
const List<(String, String)> _countPairs = [
  ('latRings', 'lonDensity'),
  ('rings', 'lonDensity'),
  ('lanes', 'segs'),
];
const List<String> _countKeys = ['orbitN', 'ghostN', 'nodeN', 'strandN', 'signals'];
const List<String> _radiusKeys = [
  'rBase', 'rDepth', 'rActive', 'rDot', 'ghostR', 'partR', 'partRDepth', 'nodeR', 'nodeRDepth',
];

int _jsRound(double v) => (v + 0.5).floor();

/// Scales dot counts (port of `scaleCounts`).
ModeOpts scaleCounts(ModeOpts opts, double scale) {
  final out = ModeOpts.of(opts);
  final done = <String>{};
  final rt = math.sqrt(scale);
  for (final (a, b) in _countPairs) {
    final va = out[a];
    final vb = out[b];
    if (va != null && vb != null && !done.contains(a) && !done.contains(b)) {
      out[a] = math.max(2, _jsRound(va * rt)).toDouble();
      out[b] = math.max(2, _jsRound(vb * rt)).toDouble();
      done..add(a)..add(b);
    }
  }
  for (final k in _countKeys) {
    final v = out[k];
    // 0 = the mode opted out of the layer; must not resurrect as a stray dot.
    if (v != null && v != 0 && !done.contains(k)) {
      out[k] = math.max(1, _jsRound(v * scale)).toDouble();
    }
  }
  final icon = out['iconD'];
  if (icon != null) out['iconD'] = math.max(0.02, icon * scale);
  return out;
}

/// Scales every radius-setting key (port of `scaleRadii`).
ModeOpts scaleRadii(ModeOpts opts, double scale) {
  final out = ModeOpts.of(opts);
  for (final k in _radiusKeys) {
    final v = out[k];
    if (v != null) out[k] = v * scale;
  }
  out['rSizeMul'] = (out['rSizeMul'] ?? 1) * scale;
  return out;
}

/// A fully resolved (mode × tuning): the geometry mode, clock multiplier and
/// scaled options the frame function consumes.
class ResolvedOrbConfig {
  const ResolvedOrbConfig._(this.mode, this.tuning, this.speed, this.opts);

  /// Geometry mode.
  final OrbMode mode;

  /// Which tuned design this came from.
  final OrbTuning tuning;

  /// Preset clock multiplier.
  final double speed;

  /// Scaled options.
  final ModeOpts opts;

  static final Map<(ThinkingOrbState, OrbTuning), ResolvedOrbConfig> _cache = {};

  /// Resolves (and caches) the config for [state] at [tuning].
  factory ResolvedOrbConfig.resolve(ThinkingOrbState state, OrbTuning tuning) {
    return _cache.putIfAbsent((state, tuning), () {
      final mode = stateToMode[state]!;
      final preset = orbPresets[mode]![tuning]!;
      var opts = ModeOpts.of(baseProfiles[mode]!);
      if (preset.count != 1) opts = scaleCounts(opts, preset.count);
      if (preset.size != 1) opts = scaleRadii(opts, preset.size);
      if (preset.extra.isNotEmpty) opts = {...opts, ...preset.extra};
      return ResolvedOrbConfig._(mode, tuning, preset.speed, opts);
    });
  }
}
