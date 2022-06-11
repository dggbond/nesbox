import 'dart:ui' as ui;
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nesbox/frame.dart';

Future<ui.Image> frameToImage(Frame frame) {
  final Completer<ui.Image> _completer = Completer();

  ui.decodeImageFromPixels(frame.pixels, frame.width, frame.height, ui.PixelFormat.rgba8888, (image) {
    _completer.complete(image);
  });

  return _completer.future;
}

class ImagePainter extends CustomPainter {
  ImagePainter(this.image);

  ui.Image image;
  final painter = Paint();

  @override
  void paint(Canvas canvas, Size size) async {
    canvas.drawImageRect(image, Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(0, 0, size.width, size.height), painter);
  }

  @override
  bool shouldRepaint(covariant ImagePainter oldDelegate) {
    return image != oldDelegate.image;
  }
}

class FrameCanvas extends HookWidget {
  const FrameCanvas({
    Key? key,
    required this.frame,
  }) : super(key: key);

  final Frame frame;

  @override
  Widget build(BuildContext context) {
    final snapshot = useFuture(frameToImage(frame));

    if (snapshot.data == null) return SizedBox();

    return CustomPaint(painter: ImagePainter(snapshot.data!));
  }
}
