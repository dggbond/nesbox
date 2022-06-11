library nesbox;

import 'dart:typed_data';

import 'cpu.dart';
import 'ppu.dart';
import 'bus.dart';
import 'frame.dart';

// the Console
class NesBox {
  BUS bus = BUS();

  int targetFps = 60;
  double fps = 60.0;
  DateTime _lastFrameAt = DateTime.now();

  CPU get cpu => bus.cpu;
  PPU get ppu => bus.ppu;

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
    while (ppu.frames == frame) {
      clock();
    }

    _updateFps();
    return ppu.frame;
  }

  _updateFps() {
    DateTime now = DateTime.now();
    if (_lastFrameAt != null) {
      fps = 1000 / now.difference(_lastFrameAt).inMilliseconds;
    }
    _lastFrameAt = now;
  }

  reset() {
    cpu.reset();
    ppu.reset();
    bus.reset();
  }
}
