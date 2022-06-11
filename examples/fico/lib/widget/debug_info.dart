import 'package:fico/nesbox_controller.dart';
import 'package:fico/widget/frame_canvas.dart';
import 'package:fico/widget/tool.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nesbox/nesbox.dart';
import 'package:nesbox/util/int_extension.dart';

class CpuFlagText extends StatelessWidget {
  const CpuFlagText(this.text, this.flag);

  final String text;
  final int flag;

  @override
  Widget build(BuildContext context) {
    return Text(text, style: TextStyle(color: flag == 1 ? Colors.green : Colors.red));
  }
}

class DebugInfoWidget extends HookWidget {
  const DebugInfoWidget({
    Key? key,
    required this.boxController,
  }) : super(key: key);

  final NesBoxController boxController;

  NesBox get box => boxController.box;

  Widget _buildStatus() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceAround, children: [
      Text('STATUS: '),
      CpuFlagText('N', box.cpu.fNegative),
      CpuFlagText('V', box.cpu.fOverflow),
      CpuFlagText('?', box.cpu.fUnused),
      CpuFlagText('B', box.cpu.fBreakCommand),
      CpuFlagText('D', box.cpu.fDecimalMode),
      CpuFlagText('I', box.cpu.fInterruptDisable),
      CpuFlagText('Z', box.cpu.fZero),
      CpuFlagText('C', box.cpu.fCarry),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
        ),
        child: Container(
            color: Color.fromRGBO(66, 66, 66, 1),
            padding: const EdgeInsets.all(8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(child: AspectRatio(aspectRatio: 1, child: FrameCanvas(frame: box.card.firstTileFrame))),
                    Margin.horizontal(4),
                    Expanded(child: AspectRatio(aspectRatio: 1, child: FrameCanvas(frame: box.card.secondTileFrame))),
                  ],
                ),
                Margin.vertical(16),
                _buildStatus(),
                Margin.vertical(16),
                Text('PC: \$${box.cpu.regPC.toHex()}'),
                Text('A: \$${box.cpu.regA.toHex()}'),
                Text('X: \$${box.cpu.regX.toHex()}'),
                Text('Y: \$${box.cpu.regY.toHex()}'),
                Text('Stack P: \$${box.cpu.regSP.toHex()}'),
                Margin.vertical(16),
                Text('Frame: ${box.ppu.frames}'),
                Text('Clocks: ${box.cpu.totalCycles}'),
                Text('FPS: ${box.fps.floor()}'),
              ],
            )));
  }
}
