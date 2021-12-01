library flutter_nes;

import "dart:typed_data";

import 'cpu.dart';
import 'ppu.dart';
import "bus.dart";
import "event_bus.dart";
import 'util/util.dart';
import 'frame.dart';

export 'cpu.dart' show CPU;
export 'ppu.dart' show PPU;
export 'cartridge.dart' show Cardtridge;
export 'bus.dart' show BUS;
export 'memory.dart' show Memory;
export 'frame.dart' show Frame;

// the Console
class NesEmulator {
  BUS bus = BUS();

  Frame bgTilesFrame = Frame(width: 0x80, height: 0x80);
  Frame spriteTilesFrame = Frame(width: 0x80, height: 0x80);

  int targetFps = 60;
  double fps = 60.0;
  DateTime _lastFrameAt;

  CPU get cpu => bus.cpu;
  PPU get ppu => bus.ppu;

  // load nes rom data
  loadGame(Uint8List data) => bus.cardtridge.load(data);

  // get one frame
  Frame _frame() {
    Frame frame;

    for (;;) {
      bus.cpu.clock();
      int times = 3;
      while (times-- > 0) {
        bus.ppu.clock();

        if (bus.ppu.frameCompleted) {
          frame = bus.ppu.frame;
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

  _renderTiles() {
    for (int x = 0; x < 0x80; x++) {
      for (int y = 0; y < 0x80; y++) {
        int number = (y / 8).floor() * 0x10 + (x / 8).floor();
        int highByte = bus.ppu.read(number * 16 + y % 8 + 8);
        int lowByte = bus.ppu.read(number * 16 + y % 8);

        int entry = highByte.getBit(7 - x % 8) << 1 | lowByte.getBit(7 - x % 8);
        bgTilesFrame.setPixel(x, y, entry);
      }
    }

    for (int x = 0; x < 0x80; x++) {
      for (int y = 0; y < 0x80; y++) {
        int number = (y / 8).floor() * 0x10 + (x / 8).floor();
        int highByte = bus.ppu.read(0x1000 + number * 16 + y % 8 + 8);
        int lowByte = bus.ppu.read(0x1000 + number * 16 + y % 8);

        int entry = highByte.getBit(7 - x % 8) << 1 | lowByte.getBit(7 - x % 8);
        spriteTilesFrame.setPixel(x, y, entry);
      }
    }
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

    _renderTiles();
    _frameLoop();
  }

  reset() {
    cpu.reset();
    ppu.reset();
    bus.cpuWorkRAM.clear();
    bus.ppuVideoRAM0.clear();
    bus.ppuVideoRAM1.clear();
    bus.ppuPalettes.clear();
  }
}
