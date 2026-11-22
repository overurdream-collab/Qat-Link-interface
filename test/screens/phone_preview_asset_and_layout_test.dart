import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/main_phone_preview.dart';

/// Guards against a silent fallback to the anonymous-person glyph.
Future<void> assertImageDecodes(String assetName) async {
  final data = await rootBundle.load(assetName);
  expect(data.lengthInBytes, greaterThan(1000),
      reason: 'Mascot asset must be a real image, not a Git LFS pointer.');
  final buffer = await ui.ImmutableBuffer.fromUint8List(
      data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes));
  final codec = await ui.instantiateImageCodecFromBuffer(buffer);
  final frame = await codec.getNextFrame();
  expect(frame.image.width, greaterThan(100));
  expect(frame.image.height, greaterThan(100));
  frame.image.dispose();
  codec.dispose();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('both approved mascot asset files decode on Flutter', () async {
    await assertImageDecodes('assets/images/maqwati_approved_character.png');
    await assertImageDecodes('assets/images/maqwati_feminine_character.png');
  });

  testWidgets('phone APK launches directly into a clean RTL login',
      (tester) async {
    tester.view.physicalSize = const Size(390, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaqwatiPhonePreview());

    expect(find.byKey(const Key('approved_glass_login_frame')), findsOneWidget);
    expect(find.byKey(const Key('login_submit')), findsOneWidget);
    expect(find.byKey(const Key('approved_masculine_login_mascot')),
        findsOneWidget);
    expect(find.byKey(const Key('login_feature_highlights')), findsOneWidget);
    expect(find.byKey(const Key('login_feature_ledger')), findsOneWidget);
    expect(find.byKey(const Key('login_feature_studio')), findsOneWidget);
    expect(find.byKey(const Key('login_feature_bookings')), findsOneWidget);
    expect(find.byKey(const Key('login_feature_insights')), findsOneWidget);
    expect(find.byType(SegmentedButton<int>), findsNothing);
    expect(find.byKey(const Key('preview_female_theme')), findsNothing);
    expect(find.text('معاينة تصميم فقط — لا حساب مالي متصل'), findsNothing);
    expect(find.text('معاينة الواجهات التجريبية'), findsNothing);
    final featurePosition = tester.getRect(
        find.byKey(const Key('login_feature_highlights')));
    // The feature row must not be completely below the visible Android screen.
    expect(featurePosition.top, lessThan(780),
        reason: 'All four approved feature tiles were pushed off-screen.');
    await tester.ensureVisible(find.byKey(const Key('login_feature_insights')));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
