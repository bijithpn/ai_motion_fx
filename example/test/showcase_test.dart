import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thinking_orb_example/main.dart';

void main() {
  for (final tab in ['ThinkingOrb', 'Image Generation', 'Voice Glow', 'Border Beam']) {
    testWidgets('$tab tab renders and controls work', (tester) async {
      tester.view
        ..devicePixelRatio = 2
        ..physicalSize = const Size(900, 1300) * 2;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(const DemoApp());
      await tester.tap(find.text(tab));
      await tester.pump(); // starts the tab animation
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull);
      // Exercise a switch + slider on every tab.
      await tester.tap(find.byType(Switch).first);
      await tester.drag(find.byType(Slider).first, const Offset(40, 0));
      await tester.pump(const Duration(milliseconds: 300));
      expect(tester.takeException(), isNull);
      await expectLater(find.byType(MaterialApp),
          matchesGoldenFile('goldens/${tab.replaceAll(' ', '_')}.png'));
    });
  }
}
