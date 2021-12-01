import 'dart:async';
import 'dart:ui' as ui;

import 'frame.dart';

Future<ui.Image> frameToImage(Frame frame) {
  final Completer<ui.Image> _completer = new Completer();

  ui.decodeImageFromPixels(frame.pixels, frame.width, frame.height, ui.PixelFormat.rgba8888, (image) {
    _completer.complete(image);
  });

  return _completer.future;
}
