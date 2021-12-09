library flutter_nes;

import 'dart:async';
import 'dart:typed_data';

import 'cpu/cpu.dart';
import 'ppu.dart';
import "bus.dart";
import 'frame.dart';
import 'util/util.dart';

// the Console
class NesEmulator {
  BUS bus = BUS();

  int targetFps = 60;
  double fps = 60.0;
  DateTime _lastFrameAt = DateTime.now();

  CPU get cpu => bus.cpu;
  PPU get ppu => bus.ppu;

  StreamController<Frame> _frameStreamController = StreamController<Frame>();
  Stream<Frame> get frameStream => _frameStreamController.stream;

  // load nes rom data
  loadGame(Uint8List bytes) => bus.card.loadNesFile(bytes);

  clock() {
    int times = cpu.clock() * 3;

    while (times-- > 0) {
      ppu.clock();
    }
  }

  stepInsruction() {
    do {
      clock();
    } while (cpu.cycles != 0);
  }

  stepFrame() {
    int frame = ppu.frames;
    while (ppu.frames == frame) {
      clock();
    }

    _frameStreamController.sink.add(ppu.frame);
    _updateFps();
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
