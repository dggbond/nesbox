import 'package:fico/nesbox_controller.dart';
import 'package:fico/widget/frame_canvas.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nesbox/nesbox.dart';

class DebugInfoWidget extends HookWidget {
  const DebugInfoWidget({
    Key? key,
    required this.boxController,
  }) : super(key: key);

  final NesBoxController boxController;

  NesBox get box => boxController.box;

  @override
  Widget build(BuildContext context) {
    return Container(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
                child: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: AspectRatio(aspectRatio: 1, child: FrameCanvas(frame: box.card.firstTileFrame))),
                const SizedBox(width: 8),
                Expanded(child: AspectRatio(aspectRatio: 1, child: FrameCanvas(frame: box.card.secondTileFrame))),
              ],
            )),
            Text(box.cpu.totalCycles.toString()),
          ],
        ));
  }
}
