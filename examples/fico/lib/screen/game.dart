import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_hooks/flutter_hooks.dart';

import 'package:nesbox/nesbox.dart';

import 'package:fico/render/painter.dart';
import 'package:fico/render/helper.dart';

class GameScreen extends HookWidget {
  NesBox box = NesBox();

  loadGame(StreamController<ui.Image> streamController) async {
    final ByteData gameBytes = await rootBundle.load('roms/Super_mario_brothers.nes');

    box.loadGame(gameBytes.buffer.asUint8List());
    box.reset();

    Timer.periodic(const Duration(milliseconds: 10), (timer) async {
      final ui.Image frameImage = await frameToImage(box.stepFrame());
      streamController.sink.add(frameImage);
    });
  }

  @override
  Widget build(BuildContext context) {
    var _frameStreamController = useStreamController<ui.Image>();
    var snapshot = useStream(_frameStreamController.stream);

    useEffect(() {
      loadGame(_frameStreamController);
    }, []);

    return GestureDetector(
      child: CustomPaint(painter: ImagePainter(snapshot.data)),
    );
  }
}
