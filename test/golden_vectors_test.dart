// Verifies the Dart geometry against the original library's frozen golden
// vectors (spec/orbs-golden.json, 72 cases, 1e-4 tolerance): every dot and
// line of every (state × size × time) must match number for number.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ai_motion_fx/src/engine/mode_frames.dart';
import 'package:ai_motion_fx/src/engine/particle_system.dart';
import 'package:ai_motion_fx/src/models/thinking_orb_config.dart';
import 'package:ai_motion_fx/src/models/thinking_orb_state.dart';

import 'golden_compare.dart';

void main() {
  final golden = jsonDecode(File('test/fixtures/orbs-golden.json').readAsStringSync())
      as Map<String, dynamic>;
  final resolved = golden['resolved'] as Map<String, dynamic>;
  final cases = (golden['cases'] as List).cast<Map<String, dynamic>>();

  ThinkingOrbState stateOf(String s) => ThinkingOrbState.values.byName(s);
  OrbTuning tuningOf(num s) => s == 20 ? OrbTuning.compact : OrbTuning.standard;

  group('resolved presets match the original', () {
    for (final entry in resolved.entries) {
      test(entry.key, () {
        final parts = entry.key.split('-');
        final cfg = ResolvedOrbConfig.resolve(stateOf(parts[0]), tuningOf(int.parse(parts[1])));
        final want = entry.value as Map<String, dynamic>;
        expect(cfg.mode.name, want['mode']);
        expect(cfg.speed, closeTo((want['speed'] as num).toDouble(), 1e-12));
        final wantOpts = (want['opts'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, (v as num).toDouble()));
        expect(cfg.opts.keys.toSet(), wantOpts.keys.toSet());
        for (final k in wantOpts.keys) {
          expect(cfg.opts[k], closeTo(wantOpts[k]!, 1e-9), reason: k);
        }
      });
    }
  });

  group('frames match golden dots/lines', () {
    final fb = FrameBuilder();
    for (final c in cases) {
      test(c['key'] as String, () {
        final cfg = ResolvedOrbConfig.resolve(
            stateOf(c['state'] as String), tuningOf(c['size'] as num));
        final size = (c['size'] as num).toDouble();
        modeFrameFor(cfg.mode)(fb, size, (c['t'] as num).toDouble(), cfg.opts);
        expectFrameMatches(
          fb,
          want: (c['dots'] as List).cast<num>(),
          wantLines: ((c['lines'] ?? const []) as List).cast<num>(),
          dotCount: c['dotCount'] as int,
          lineCount: c['lineCount'] as int,
        );
      });
    }
  });
}
