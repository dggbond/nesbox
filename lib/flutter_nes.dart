library flutter_nes;

import 'dart:async';
import 'dart:typed_data';

import 'cpu.dart';
import 'ppu.dart';
import "bus.dart";
import 'frame.dart';

export 'cpu.dart';
export 'cpu_instructions.dart';
export 'ppu.dart' show PPU;
export 'cartridge.dart' show Cardtridge;
export 'bus.dart' show BUS;
export 'frame.dart' show Frame;

// the Console
class NesEmulator {
  BUS bus = BUS();

  int targetFps = 60;
  double fps = 60.0;
  DateTime _lastFrameAt = DateTime.now();

  CPU get cpu => bus.cpu;
  PPU get ppu => bus.ppu;

  StreamController<Frame> frameStream = StreamController<Frame>();

  // load nes rom data
  loadGame(Uint8List bytes) => bus.card.loadNesFile(bytes);

  clock() async {
    int times = cpu.clock() * 3;
    while (times-- > 0) {
      ppu.clock();

      if (ppu.frameCompleted) {
        frameStream.sink.add(ppu.frame);
        _updateFps();
      }
    }
  }

  step() {
    do {
      clock();
    } while (cpu.cycles != 0);
  }

  _updateFps() {
    DateTime now = DateTime.now();
    if (_lastFrameAt != null) {
      fps = 1000 / now.difference(_lastFrameAt).inMilliseconds;
    }
    _lastFrameAt = now;
  }

  powerOn() async {
    reset();

    while (true) {
      await clock();
    }
  }

  reset() {
    cpu.reset();
    ppu.reset();
    bus.reset();
  }
}
