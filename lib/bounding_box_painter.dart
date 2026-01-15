import 'package:flutter/material.dart';

class BoundingBoxPainter extends CustomPainter {
  final List<Rect> rects;
  final Size imageSize; // Ukuran asli foto
  final Size widgetSize; // Ukuran widget/layar yang tampil

  BoundingBoxPainter(this.rects, this.imageSize, this.widgetSize);

  @override
  void paint(Canvas canvas, Size size) {
    // log(
    //   "BoundingBoxPainter(rectsLen: ${rects.length}, imgSize: Size(${imageSize.width},${imageSize.height}), widgetSize: Size(${widgetSize.width},${widgetSize.height}))",
    // );
    final paint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.0
          ..color = Colors.amber;

    // Hitung faktor skala
    final scaleX = widgetSize.width / imageSize.width;
    final scaleY = widgetSize.height / imageSize.height;

    for (var rect in rects) {
      // Transformasi koordinat dari ukuran foto ke ukuran layar
      // final scaledRect = Rect.fromLTRB(100, 100, 200, 200);

      final scaledRect = Rect.fromLTRB(
        rect.left * scaleX,
        rect.top * scaleY,
        rect.right * scaleX,
        rect.bottom * scaleY,
      );

      // Gambar kotak
      canvas.drawRect(scaledRect, paint);

      // // Gambar Label
      // if (detectedObject.labels.isNotEmpty) {
      //   final textPainter = TextPainter(
      //     text: TextSpan(
      //       text: detectedObject.labels.first.text,
      //       style: TextStyle(
      //         color: Colors.black,
      //         backgroundColor: Colors.amber,
      //       ),
      //     ),
      //     textDirection: TextDirection.ltr,
      //   )..layout();
      //   textPainter.paint(canvas, Offset(scaledRect.left, scaledRect.top - 20));
      // }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
