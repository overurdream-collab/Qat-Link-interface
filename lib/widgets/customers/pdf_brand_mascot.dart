import 'dart:ui' as ui;
import 'package:flutter/services.dart';

/// Approved character, uncropped, in printed reports. Asset errors propagate
/// to the export error state; a blank badge must not hide a missing character.
abstract final class PdfBrandMascot {
  static final _images = <bool, Future<ui.Image>>{};

  static Future<ui.Image> _load(bool feminine) async {
    final data = await rootBundle.load(feminine
        ? 'assets/images/maqwati_feminine_character.png'
        : 'assets/images/maqwati_approved_character.png');
    final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
    try {
      return (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
  }

  static Future<void> draw(
    ui.Canvas canvas, {
    required double x,
    required double y,
    double size = 70,
    bool feminine = false,
  }) async {
    final bounds = ui.Rect.fromLTWH(x, y, size, size);
    final shape =
        ui.RRect.fromRectAndRadius(bounds, ui.Radius.circular(size * .22));
    canvas.drawRRect(
        shape,
        ui.Paint()
          ..color = feminine
              ? const ui.Color(0xFFFFEFF6)
              : const ui.Color(0xFFF2F3FF));
    final image = await _images.putIfAbsent(feminine, () => _load(feminine));
    final w = image.width.toDouble(), h = image.height.toDouble();
    final scale = size / (w > h ? w : h);
    final target = ui.Rect.fromLTWH(x + (size - w * scale) / 2,
        y + (size - h * scale) / 2, w * scale, h * scale);
    canvas.save();
    canvas.clipRRect(shape);
    canvas.drawImageRect(image, ui.Rect.fromLTWH(0, 0, w, h), target,
        ui.Paint()..filterQuality = ui.FilterQuality.high);
    canvas.restore();
    canvas.drawRRect(
        shape,
        ui.Paint()
          ..style = ui.PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = const ui.Color(0xFFD4A13E));
  }
}
