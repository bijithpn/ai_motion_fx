import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_motion_fx/ai_motion_fx.dart';

Widget _host(Widget child, {bool reduce = false}) => MaterialApp(
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: reduce),
        child: c!,
      ),
      home: Scaffold(body: Center(child: child)),
    );

Future<MemoryImage> _picture(WidgetTester t) async {
  late MemoryImage image;
  await t.runAsync(() async {
    final rec = ui.PictureRecorder();
    Canvas(rec).drawRect(const Rect.fromLTWH(0, 0, 64, 64), Paint()..color = const Color(0xFF7C5CFF));
    final img = await rec.endRecording().toImage(64, 64);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    image = MemoryImage(bytes!.buffer.asUint8List());
  });
  return image;
}

void main() {
  group('ThinkingVoiceGlow', () {
    testWidgets('wraps the child, animates, and lets touches through', (t) async {
      var taps = 0;
      await t.pumpWidget(_host(ThinkingVoiceGlow(
        level: 0.7,
        child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: () => taps++, child: const SizedBox(width: 300, height: 56)),
      )));
      await t.pump(const Duration(milliseconds: 300));
      expect(t.takeException(), isNull);
      expect(t.binding.hasScheduledFrame, isTrue);
      await t.tapAt(t.getCenter(find.byType(GestureDetector)));
      expect(taps, 1);
    });

    testWidgets('every type and variant renders', (t) async {
      for (final type in ThinkingVoiceGlowType.values) {
        for (final variant in ThinkingGlowVariant.values) {
          await t.pumpWidget(_host(ThinkingVoiceGlow(
            type: type,
            colorVariant: variant,
            level: 0.5,
            processing: variant.index.isEven,
            child: const SizedBox(width: 240, height: 56),
          )));
          await t.pump(const Duration(milliseconds: 120));
          expect(t.takeException(), isNull);
        }
      }
    });

    testWidgets('paused and reduced motion stop the ticker', (t) async {
      await t.pumpWidget(_host(const ThinkingVoiceGlow(
        paused: true,
        child: SizedBox(width: 200, height: 50),
      )));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.binding.hasScheduledFrame, isFalse);

      await t.pumpWidget(_host(const ThinkingVoiceGlow(child: SizedBox(width: 200, height: 50)), reduce: true));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.binding.hasScheduledFrame, isFalse);
    });
  });

  group('ThinkingBeam', () {
    testWidgets('every size and variant renders', (t) async {
      for (final size in ThinkingBeamSize.values) {
        for (final variant in ThinkingGlowVariant.values) {
          await t.pumpWidget(_host(ThinkingBeam(
            size: size,
            colorVariant: variant,
            child: const SizedBox(width: 160, height: 80),
          )));
          await t.pump(const Duration(milliseconds: 150));
          expect(t.takeException(), isNull);
        }
      }
    });

    testWidgets('custom colours, zero strength and odd radii are fine', (t) async {
      await t.pumpWidget(_host(ThinkingBeam(
        colors: const [Colors.red, Colors.blue],
        strength: 0,
        borderRadius: BorderRadius.zero,
        child: const SizedBox(width: 100, height: 40),
      )));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.takeException(), isNull);
    });

    testWidgets('paused beam does not tick', (t) async {
      await t.pumpWidget(_host(const ThinkingBeam(paused: true, child: SizedBox(width: 100, height: 40))));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.binding.hasScheduledFrame, isFalse);
    });
  });

  group('ThinkingImageReveal', () {
    testWidgets('fills the available space when no size is given', (t) async {
      final img = await _picture(t);
      await t.pumpWidget(_host(SizedBox(width: 200, height: 150, child: ThinkingImageReveal(images: [img]))));
      expect(t.getSize(find.byType(ThinkingImageReveal)), const Size(200, 150));
    });

    testWidgets('reveals the picture, calls back, and can be replayed', (t) async {
      final img = await _picture(t);
      final controller = ThinkingImageRevealController();
      var revealed = 0;
      await t.pumpWidget(_host(ThinkingImageReveal(
        images: [img],
        autoReveal: false,
        controller: controller,
        width: 120,
        height: 120,
        onRevealed: () => revealed++,
      )));
      // let the picture decode
      for (var i = 0; i < 5; i++) {
        await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(controller.isRevealed, isFalse); // armed only after replay()
      expect(revealed, 0);

      controller.replay();
      for (var i = 0; i < 100; i++) {
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(revealed, 1);
      expect(controller.isRevealed, isTrue);
    });

    testWidgets('every preset renders mid-reveal', (t) async {
      final img = await _picture(t);
      for (final preset in ThinkingRevealPreset.values) {
        await t.pumpWidget(_host(ThinkingImageReveal(
          key: ValueKey(preset),
          images: [img],
          preset: preset,
          width: 100,
          height: 100,
        )));
        for (var i = 0; i < 4; i++) {
          await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 60)));
          await t.pump(const Duration(milliseconds: 500));
        }
        expect(t.takeException(), isNull);
      }
    });

    testWidgets('a broken image keeps the loader churning without errors', (t) async {
      await t.pumpWidget(_host(const ThinkingImageReveal(
        images: [NetworkImage('https://invalid.example/none.png')],
        width: 100,
        height: 100,
      )));
      for (var i = 0; i < 20; i++) {
        await t.pump(const Duration(milliseconds: 200));
      }
      expect(t.takeException(), isNull);
    });

    testWidgets('reduced motion shows the finished picture and stops', (t) async {
      final img = await _picture(t);
      await t.pumpWidget(_host(ThinkingImageReveal(images: [img], width: 100, height: 100), reduce: true));
      await t.pump(const Duration(milliseconds: 100));
      expect(t.binding.hasScheduledFrame, isFalse);
    });
  });
}
