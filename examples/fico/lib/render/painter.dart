import 'dart:ui' as ui;
import 'package:flutter/material.dart';

class ImagePainter extends CustomPainter {
  ImagePainter(this.image);

  ui.Image? image;
  final painter = Paint();

  @override
  void paint(Canvas canvas, Size size) async {
    if (image == null) return;

    canvas.drawImageRect(image!, Rect.fromLTWH(0, 0, image!.width.toDouble(), image!.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height), painter);
  }

  @override
  bool shouldRepaint(covariant ImagePainter oldDelegate) {
    return image != oldDelegate.image;
  }
}
