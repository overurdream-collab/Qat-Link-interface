import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden comparison must not approve an empty first frame while an asset is
/// still decoding. pumpAndSettle alone does not wait for asynchronous image I/O.
Future<void> auditDecodedImages(WidgetTester tester) async {
  for (final element in find.byType(Image).evaluate().toList()) {
    final widget = element.widget as Image;
    Object? failure;
    await tester.runAsync(() => precacheImage(widget.image, element,
        onError: (error, stack) => failure = error));
    expect(failure, isNull,
        reason: 'Bundled image must decode: ${widget.image}');
  }
  await tester.pumpAndSettle();
  for (final image in tester.widgetList<RawImage>(find.byType(RawImage))) {
    expect(image.image, isNotNull,
        reason: 'A visible image must have a decoded frame before capture');
  }
}
