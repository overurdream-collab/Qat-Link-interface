import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:qat_link/widgets/customers/pdf_brand_mascot.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  for (final feminine in [false, true]) {
    test('PDF preserves the full ${feminine ? 'female' : 'male'} character',
        () async {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      await PdfBrandMascot.draw(canvas,
          x: 5, y: 5, size: 90, feminine: feminine);
      final picture = recorder.endRecording();
      final image = await picture.toImage(100, 100);
      await expectLater(
          image,
          matchesGoldenFile(
              'goldens/pdf/character_${feminine ? 'female' : 'male'}.png'));
      image.dispose();
      picture.dispose();
    });
  }
}
