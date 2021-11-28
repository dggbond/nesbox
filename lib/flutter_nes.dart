library flutter_nes;

import "dart:typed_data";

import 'cartridge.dart';
import "cpu.dart";
import "ppu.dart";
import "bus.dart";
import "memory.dart";
import "event_bus.dart";
import 'util/logger.dart';
import 'util/throttle.dart';
import 'frame.dart';

// the Console
class NesEmulator {
  NesEmulator() {
    cpu = CPU(bus);
    ppu = PPU(bus);

    bus.cpu = cpu;
    bus.ppu = ppu;
    bus.cpuRAM = cpuWorkRAM;
    bus.ppuRAM = ppuVideoRAM;
    bus.ppuPalettes = ppuPalettes;
    bus.cardtridge = cardtridge;
  }

  BUS bus = BUS();

  CPU cpu;
  PPU ppu;
  Memory cpuWorkRAM = Memory(0x800);

  // In most case PPU only use 2kb RAM and mirroring the name tables
  // but when four-screen mirroring it will use an additional 2kb RAM.
  // In this emulator, i ignore four-screen case, so i just need 2kb RAM.
  Memory ppuVideoRAM = Memory(0x800);
  Memory ppuPalettes = Memory(0x20);
  Cardtridge cardtridge = Cardtridge();

  int targetFps = 60;
  double fps = 60.0;
  DateTime _lastFrameAt;

  // load nes rom data
  loadGame(Uint8List data) => cardtridge.load(data);

  // get one frame
  Frame _frame() {
    Frame frame;

    for (;;) {
      int cpuCycles = cpu.tick();
      int ppuCycles = cpuCycles * 3;

      while (ppuCycles-- > 0) {
        ppu.tick();

        if (ppu.frameCompleted) {
          frame = ppu.frame;
        }
      }

      if (frame != null) return frame;
    }
  }

  _frameLoop() async {
    var frameEmitter = new Throttle(() {
      _updateFps();
      outerBus.emit('FrameDone', _frame());
    }, 10);
    frameEmitter.loop();
  }

  _updateFps() {
    DateTime now = DateTime.now();
    if (_lastFrameAt != null) {
      fps = 1000 / now.difference(_lastFrameAt).inMilliseconds;
    }
    _lastFrameAt = now;
  }

  on(String eventName, EventCallback f) {
    outerBus.on(eventName, f);
  }

  off(String eventName, [EventCallback f]) {
    outerBus.off(eventName, f);
  }

  powerOn() {
    cpu.powerOn();
    ppu.powerOn();

    _frameLoop();
  }

  reset() {
    cpu.reset();
    ppu.reset();
    cpuWorkRAM.clear();
    ppuVideoRAM.clear();
    ppuPalettes.clear();
  }
}
