import 'dart:async';
import 'dart:ui';

import 'package:nesbox/frame.dart';

Future<Image> frameToImage(Frame frame) {
  final Completer<Image> _completer = new Completer();

  decodeImageFromPixels(frame.pixels, frame.width, frame.height, PixelFormat.rgba8888, (image) {
    _completer.complete(image);
  });

  return _completer.future;
}
