import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/widgets/home/premium_home_hero.dart';

void main() {
  for (final width in <double>[320, 360, 390, 430]) {
    testWidgets('Premium hero fits RTL width $width', (tester) async {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
          body: Directionality(
            textDirection: TextDirection.rtl,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: PremiumHomeHero(),
            ),
          ),
        ),
      ));
      expect(find.text('مقوتي لينك'), findsOneWidget);
      expect(find.text('كل عملية بموافقة الطرفين'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
