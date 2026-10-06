// Visual regression frames. Orbs render the reduced-motion frame (t = 0.6),
// the same deterministic frame the original shows to reduced-motion users.
// Numeric parity with the original is proven by golden_vectors_test.dart;
// these images guard the painter (ink, alpha, z-order, layout) against drift.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_motion_fx/ai_motion_fx.dart';

Widget _grid(List<Widget> cells, {required bool dark, required double cell}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(brightness: dark ? Brightness.dark : Brightness.light),
    home: Scaffold(
      backgroundColor: dark ? const Color(0xFF111111) : const Color(0xFFFFFFFF),
      body: Center(
        child: SizedBox(
          width: cell * 3,
          child: Wrap(
            children: [
              for (final c in cells) SizedBox.square(dimension: cell, child: Center(child: c)),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  for (final dark in [false, true]) {
    for (final size in [20.0, 64.0]) {
      final name = '${dark ? 'dark' : 'light'}_${size.toInt()}';
      testWidgets('all states — $name', (tester) async {
        tester.view
          ..devicePixelRatio = 4
          ..physicalSize = const Size(300, 300) * 4;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_grid([
          for (final s in ThinkingOrbState.values)
            ThinkingOrb(state: s, size: size, reducedMotion: true),
        ], dark: dark, cell: 96));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/states_$name.png'));
      });
    }
  }

  testWidgets('shaping — every shape', (tester) async {
    tester.view
      ..devicePixelRatio = 4
      ..physicalSize = const Size(400, 110) * 4;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Wrap(spacing: 24, children: [
            for (final s in ThinkingOrbShape.values)
              ThinkingOrb(
                  state: ThinkingOrbState.shaping,
                  shape: s,
                  size: 64,
                  theme: ThinkingOrbTheme.light,
                  reducedMotion: true),
          ]),
        ),
      ),
    ));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/shapes.png'));
  });

  testWidgets('voice, image and beam', (tester) async {
    tester.view
      ..devicePixelRatio = 3
      ..physicalSize = const Size(360, 240) * 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(brightness: Brightness.light),
      home: const Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: Wrap(spacing: 24, runSpacing: 24, alignment: WrapAlignment.center, children: [
            ThinkingVoiceOrb(
                state: VoiceOrbState.listening, intensity: 0.9, size: 96, reducedMotion: true),
            ThinkingVoiceOrb(state: VoiceOrbState.idle, size: 96, reducedMotion: true),
            ThinkingImageOrb(size: 96, animate: false),
            ThinkingBorderBeam(
              reducedMotion: true,
              child: SizedBox(width: 120, height: 60),
            ),
          ]),
        ),
      ),
    ));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/extras.png'));
  });
}
