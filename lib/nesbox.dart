library nesbox;

import 'dart:typed_data';

import 'package:nesbox/cartridge.dart';

import 'cpu.dart';
import 'ppu.dart';
import 'bus.dart';
import 'frame.dart';

// the Console
class NesBox {
  BUS bus = BUS();

  double fps = 0;

  CPU get cpu => bus.cpu;
  PPU get ppu => bus.ppu;
  Cardtridge get card => bus.card;

  // load nes rom data
  loadGame(Uint8List bytes) => bus.card.loadNesFile(bytes);

  clock() {
    int times = cpu.clock() * 3;

    while (times-- > 0) {
      ppu.clock();
    }
  }

  stepInstruction() {
    do {
      clock();
    } while (cpu.cycles != 0);
  }

  Frame stepFrame() {
    int frame = ppu.frames;
    var start = DateTime.now();
    while (ppu.frames == frame) {
      clock();
    }

    // update fps
    fps = 1000 / DateTime.now().difference(start).inMilliseconds;
    return ppu.frame;
  }

  reset() {
    cpu.reset();
    ppu.reset();
    bus.reset();
  }
}
