import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import 'package:nesbox/nesbox.dart';

import 'package:fico/render/painter.dart';
import 'package:fico/render/helper.dart';

class GameScreenState extends State {
  NesBox box = NesBox();

  ui.Image? frameImage;

  @override
  void initState() {
    super.initState();

    loadGame();
  }

  loadGame() async {
    final ByteData gameBytes = await rootBundle.load('roms/Super_mario_brothers.nes');

    box.loadGame(gameBytes.buffer.asUint8List());
    box.reset();
    box.stepFrame();

    box.frameStream.listen((newFrame) async {
      final ui.Image newImage = await frameToImage(newFrame);
      Timer(const Duration(milliseconds: 10), () {
        // DateTime start = DateTime.now();
        box.stepFrame();
        // log('${DateTime.now().difference(start).inMilliseconds}ms');
      });

      setState(() {
        frameImage = newImage;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      child: CustomPaint(painter: ImagePainter(frameImage)),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({Key? key}) : super(key: key);

  @override
  State<StatefulWidget> createState() => GameScreenState();
}
