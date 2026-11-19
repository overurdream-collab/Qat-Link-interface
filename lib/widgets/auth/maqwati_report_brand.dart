import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'auth_brand_hero.dart';

/// Paints the approved offline logo in generated Flutter-rasterized PDF pages.
/// If an image cannot be read, caller's existing textual title remains visible.
Future<void> paintMaqwatiReportLogo(ui.Canvas canvas, {
  double x = 18, double y = 13, double width = 246, double height = 81,
}) async {
  ui.Codec? codec;
  ui.Image? image;
  try {
    final asset = await rootBundle.load(MaqwatiBrandAssets.horizontalLogo);
    codec = await ui.instantiateImageCodec(asset.buffer.asUint8List());
    final frame = await codec.getNextFrame();
    image = frame.image;
    final destination = ui.Rect.fromLTWH(x,y,width,height);
    canvas.drawRRect(
      ui.RRect.fromRectAndRadius(destination, const ui.Radius.circular(10)),
      ui.Paint()..color=const ui.Color(0xFFFFFFFF),
    );
    canvas.save();
    canvas.clipRRect(ui.RRect.fromRectAndRadius(
      destination, const ui.Radius.circular(10)));
    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0,0,image.width.toDouble(),image.height.toDouble()),
      destination,
      ui.Paint()..filterQuality=ui.FilterQuality.high,
    );
    canvas.restore();
  } catch (_) {
    // Never interrupt an accounting report because a decorative image failed.
  } finally {
    image?.dispose();
    codec?.dispose();
  }
}
