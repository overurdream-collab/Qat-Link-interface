import 'dart:ui' as ui;
import 'dart:io';
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
      final proof = Directory('build/ui-pdf-proof')..createSync(recursive: true);
      final bytes = (await image.toByteData(format: ui.ImageByteFormat.png))!;
      File('${proof.path}/character_${feminine ? 'female' : 'male'}.png')
          .writeAsBytesSync(bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes));
      await expectLater(
          // Compare PNG bytes directly: this is a plain test, not a widget
          // test with a runAsync zone for the matcher's ui.Image branch.
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
          matchesGoldenFile(
              'goldens/pdf/character_${feminine ? 'female' : 'male'}.png'));
      image.dispose();
      picture.dispose();
    });
  }
}
