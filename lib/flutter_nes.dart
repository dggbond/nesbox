library flutter_nes;

import 'dart:async';
import 'dart:typed_data';

import 'cpu.dart';
import 'ppu.dart';
import "bus.dart";
import 'util/util.dart';
import 'frame.dart';

export 'cpu.dart' show CPU;
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

        await Future.delayed(Duration(milliseconds: 16));
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

  powerOn() {
    // CPU power-up state see: https://wiki.nesdev.com/w/index.php/CPU_power_up_state
    cpu.regPC = cpu.read16Bit(0xfffc);
    cpu.regPS = 0x34;
    cpu.regSP = 0xfd;
    cpu.regA = 0x00;
    cpu.regX = 0x00;
    cpu.regY = 0x00;

    ppu.regCTRL = 0x00;
    ppu.regMASK = 0x00;
    ppu.regSTATUS = 0x00;
    ppu.regOAMADDR = 0x00;
    ppu.regSCROLL = 0x00;
    ppu.regADDR = 0x00;
  }

  reset() {
    cpu.reset();
    ppu.reset();

    bus.cpuWorkRAM.fill(0x00);
    bus.ppuVideoRAM0.fill(0x00);
    bus.ppuVideoRAM1.fill(0x00);
    bus.ppuPalettes.fill(0x00);
  }
}
