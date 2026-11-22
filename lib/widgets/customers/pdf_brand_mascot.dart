import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Small shared offline mascot mark for rasterized Arabic A4 statements.
/// Uses the same approved character asset as onboarding and merchant chrome.
/// Missing assets leave a neutral framed badge, never a fabricated logo.
abstract final class PdfBrandMascot {
  static Future<ui.Image?>? _imageLoad;

  static Future<ui.Image?> _load() async {
    try {
      final data = await rootBundle.load(
        'assets/images/maqwati_approved_character.png',
      );
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
      );
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  static Future<void> draw(
    ui.Canvas canvas, {
    required double x,
    required double y,
    double size = 70,
  }) async {
    final bounds = ui.Rect.fromLTWH(x, y, size, size);
    final radius = ui.Radius.circular(size * .22);
    final shape = ui.RRect.fromRectAndRadius(bounds, radius);
    canvas.drawRRect(
      shape,
      ui.Paint()..color = const ui.Color(0xFFECF8F6),
    );
    final image = await (_imageLoad ??= _load());
    if (image != null) {
      final w = image.width.toDouble();
      final h = image.height.toDouble();
      final edge = w < h ? w : h;
      final source = ui.Rect.fromLTWH(
        (w - edge) / 2,
        (h - edge) / 2,
        edge,
        edge,
      );
      canvas.save();
      canvas.clipRRect(shape);
      canvas.drawImageRect(
        image,
        source,
        bounds,
        ui.Paint()..filterQuality = ui.FilterQuality.high,
      );
      canvas.restore();
    }
    canvas.drawRRect(
      shape,
      ui.Paint()
        ..style = ui.PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const ui.Color(0xFFD4A13E),
    );
  }
}
