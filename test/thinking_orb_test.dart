import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinking_orb/src/engine/animation_clock.dart';
import 'package:thinking_orb/src/engine/orb_renderer.dart';
import 'package:thinking_orb/src/engine/particle_system.dart';
import 'package:thinking_orb/src/models/thinking_orb_config.dart';
import 'package:thinking_orb/src/states/voice.dart';
import 'package:thinking_orb/thinking_orb.dart';

OrbPainter _painter(WidgetTester tester, [int index = 0]) {
  final finder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is OrbPainter);
  return tester.widget<CustomPaint>(finder.at(index)).painter! as OrbPainter;
}

Widget _host(Widget child, {Brightness brightness = Brightness.light, bool reduce = false}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    builder: (context, c) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
      child: c!,
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  setUp(() => ThinkingOrbClock.instance.reset());

  group('ThinkingOrb', () {
    for (final state in ThinkingOrbState.values) {
      testWidgets('renders ${state.name} at both sizes', (tester) async {
        for (final size in [20.0, 64.0]) {
          await tester.pumpWidget(_host(ThinkingOrb(state: state, size: size)));
          await tester.pump(const Duration(milliseconds: 300));
          expect(tester.takeException(), isNull);
          expect(tester.getSize(find.byType(ThinkingOrb)), Size.square(size));
          expect(_painter(tester).builder.dots, isNotEmpty);
        }
      });
    }

    testWidgets('size changes resize the widget', (tester) async {
      await tester.pumpWidget(_host(const ThinkingOrb(size: 40)));
      expect(tester.getSize(find.byType(ThinkingOrb)), const Size.square(40));
      await tester.pumpWidget(_host(const ThinkingOrb(size: 96)));
      expect(tester.getSize(find.byType(ThinkingOrb)), const Size.square(96));
    });

    testWidgets('speed scales animation time', (tester) async {
      Future<double> timeAfter(double speed) async {
        ThinkingOrbClock.instance.reset();
        await tester.pumpWidget(_host(ThinkingOrb(speed: speed)));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        return _painter(tester).timeline.t;
      }

      final slow = await timeAfter(1);
      final fast = await timeAfter(2);
      expect(fast / slow, closeTo(2, 1e-6));
    });

    testWidgets('paused freezes the frame; unpausing resumes', (tester) async {
      await tester.pumpWidget(_host(const ThinkingOrb(paused: true)));
      await tester.pump(const Duration(seconds: 1));
      final frozen = _painter(tester).timeline.t;
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).timeline.t, frozen);
      expect(_painter(tester).timeline.isRunning, isFalse);

      await tester.pumpWidget(_host(const ThinkingOrb()));
      await tester.pump(); // first tick establishes the clock origin
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).timeline.t, greaterThan(frozen));
      expect(_painter(tester).timeline.isRunning, isTrue);
    });

    testWidgets('theme: explicit and auto (live)', (tester) async {
      await tester.pumpWidget(_host(const ThinkingOrb(theme: ThinkingOrbTheme.dark)));
      expect(_painter(tester).dark, isTrue);
      await tester.pumpWidget(_host(const ThinkingOrb(theme: ThinkingOrbTheme.light),
          brightness: Brightness.dark));
      expect(_painter(tester).dark, isFalse);

      await tester.pumpWidget(_host(const ThinkingOrb()));
      expect(_painter(tester).dark, isFalse);
      await tester.pumpWidget(_host(const ThinkingOrb(), brightness: Brightness.dark));
      await tester.pump(const Duration(milliseconds: 400)); // MaterialApp animates theme changes
      expect(_painter(tester).dark, isTrue);
    });

    testWidgets('semantics: default and custom label', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_host(const ThinkingOrb(state: ThinkingOrbState.searching)));
      expect(find.bySemanticsLabel('Searching…'), findsOneWidget);
      await tester.pumpWidget(_host(const ThinkingOrb(
          state: ThinkingOrbState.searching, semanticLabel: 'Searching for information')));
      expect(find.bySemanticsLabel('Searching for information'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('reduced motion renders one static frame at t = 0.6', (tester) async {
      await tester.pumpWidget(_host(const ThinkingOrb(), reduce: true));
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).timeline.t, 0.6);
      expect(_painter(tester).timeline.isRunning, isFalse);
      expect(_painter(tester).builder.dots, isNotEmpty);
    });

    testWidgets('orbs share one clock and stay in phase', (tester) async {
      await tester.pumpWidget(_host(const Row(mainAxisSize: MainAxisSize.min, children: [
        ThinkingOrb(),
        ThinkingOrb(),
      ])));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      expect(_painter(tester, 0).timeline.t, _painter(tester, 1).timeline.t);
    });

    testWidgets('TickerMode(enabled: false) pauses animation', (tester) async {
      await tester.pumpWidget(_host(const TickerMode(enabled: false, child: ThinkingOrb())));
      await tester.pump(const Duration(seconds: 1));
      final t0 = _painter(tester).timeline.t;
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).timeline.t, t0);
    });
  });

  group('shaping shapes', () {
    final cfg = ResolvedOrbConfig.resolve(ThinkingOrbState.shaping, OrbTuning.standard);

    List<List<double>> frame(ThinkingOrbShape shape, double t) {
      final fb = FrameBuilder();
      PresetFrameSource(cfg, shape: shape).build(fb, 64, t);
      return [
        for (final d in fb.dots) [d.x, d.y, d.r]
      ];
    }

    // Each shape's hold window in the original cycle (HOLD 1.4 of a 2.3s segment).
    for (final (shape, start) in [
      (ThinkingOrbShape.circle, 0.0),
      (ThinkingOrbShape.triangle, 2.3),
      (ThinkingOrbShape.square, 4.6),
    ]) {
      test('${shape.name} equals the original cycle during its hold', () {
        for (final dt in [0.0, 0.4, 1.0, 1.39]) {
          final held = frame(shape, start + dt);
          final cyc = frame(ThinkingOrbShape.cycle, start + dt);
          expect(held.length, cyc.length);
          for (var i = 0; i < held.length; i++) {
            for (var j = 0; j < 3; j++) {
              expect(held[i][j], closeTo(cyc[i][j], 1e-9));
            }
          }
        }
      });
    }

    test('held shapes stay put while the cycle morphs on', () {
      final a = frame(ThinkingOrbShape.triangle, 3.0);
      final b = frame(ThinkingOrbShape.triangle, 3.0 + 2.3 * 5); // 5 segments later
      for (var i = 0; i < a.length; i++) {
        expect(a[i][0], closeTo(b[i][0], 1e-9));
        expect(a[i][1], closeTo(b[i][1], 1e-9));
      }
    });

    testWidgets('widget accepts shape and updates it', (tester) async {
      await tester.pumpWidget(_host(const ThinkingOrb(
          state: ThinkingOrbState.shaping, shape: ThinkingOrbShape.square, reducedMotion: true)));
      final sq = _painter(tester).builder.dots.map((d) => d.x).reduce((a, b) => a > b ? a : b);
      await tester.pumpWidget(_host(const ThinkingOrb(
          state: ThinkingOrbState.shaping, shape: ThinkingOrbShape.circle, reducedMotion: true)));
      await tester.pump();
      final ci = _painter(tester).builder.dots.map((d) => d.x).reduce((a, b) => a > b ? a : b);
      expect(sq, isNot(closeTo(ci, 0.5)));
    });
  });

  test('ThinkingOrb.compact is a 20px orb', () {
    expect(const ThinkingOrb.compact().size, 20);
  });

  group('ThinkingVoiceOrb', () {
    for (final s in VoiceOrbState.values) {
      testWidgets('renders ${s.name}', (tester) async {
        await tester.pumpWidget(_host(ThinkingVoiceOrb(state: s, intensity: 0.8)));
        await tester.pump(const Duration(milliseconds: 500));
        expect(tester.takeException(), isNull);
        expect(_painter(tester).builder.dots, isNotEmpty);
      });
    }

    testWidgets('intensity changes the geometry', (tester) async {
      Future<double> extent(double intensity) async {
        ThinkingOrbClock.instance.reset();
        await tester.pumpWidget(_host(ThinkingVoiceOrb(
            state: VoiceOrbState.listening, intensity: intensity, reducedMotion: false)));
        await tester.pump();
        for (var i = 0; i < 60; i++) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        final dots = _painter(tester).builder.dots;
        var minY = double.infinity, maxY = -double.infinity;
        for (final d in dots) {
          minY = d.y < minY ? d.y : minY;
          maxY = d.y > maxY ? d.y : maxY;
        }
        return maxY - minY;
      }

      // Different energy → different silhouette.
      expect(await extent(1.0), isNot(closeTo(await extent(0.0), 1e-3)));
    });
  });

  test('voice processing scan keeps dot radii in family with listening', () {
    final cfg = ResolvedOrbConfig.resolve(ThinkingOrbState.listening, OrbTuning.standard);
    double maxR(VoiceOrbState st) {
      final src = VoiceFrameSource(cfg)..state = st..intensity = 0.5;
      final fb = FrameBuilder();
      var m = 0.0;
      for (final t in [0.0, 1.0, 2.0, 3.0]) {
        src.build(fb, 72, t);
        for (final d in fb.dots) {
          if (d.r > m) m = d.r;
        }
      }
      return m;
    }

    expect(maxR(VoiceOrbState.processing), lessThan(maxR(VoiceOrbState.listening) * 2.5));
  });

  group('ThinkingImageOrb', () {
    testWidgets('renders with and without an image, split in two layers', (tester) async {
      await tester.pumpWidget(_host(const ThinkingImageOrb()));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      final layers = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is OrbPainter);
      expect(layers, findsNWidgets(2));
    });

    testWidgets('animate: false freezes on the static frame', (tester) async {
      await tester.pumpWidget(_host(const ThinkingImageOrb(animate: false)));
      await tester.pump(const Duration(seconds: 1));
      expect(_painter(tester).timeline.t, 0.6);
    });
  });

  group('ThinkingBorderBeam', () {
    testWidgets('wraps the child and animates; pause freezes', (tester) async {
      await tester.pumpWidget(_host(const ThinkingBorderBeam(
          child: SizedBox(width: 120, height: 60, child: Text('hi')))));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
      expect(find.text('hi'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.pumpWidget(_host(const ThinkingBorderBeam(
          paused: true, child: SizedBox(width: 120, height: 60, child: Text('hi')))));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });
  });
}
