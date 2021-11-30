library flutter_nes;

import "dart:typed_data";

import 'cpu.dart';
import "bus.dart";
import "event_bus.dart";
import 'util/util.dart';
import 'frame.dart';

export 'cpu.dart' show CPU;
export 'PPU.dart' show PPU;
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
  int cycle = 0;
  double fps = 60.0;
  DateTime _lastFrameAt;

  // load nes rom data
  loadGame(Uint8List data) => bus.cardtridge.load(data);

  // get one frame
  Frame _frame() {
    Frame frame;

    for (;;) {
      int cpuCycles = bus.cpu.tick();
      int ppuCycles = cpuCycles * 3;
      cycle += cpuCycles;

      while (ppuCycles-- > 0) {
        bus.ppu.tick();

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
        int highByte = bus.ppuRead(number * 16 + y % 8 + 8);
        int lowByte = bus.ppuRead(number * 16 + y % 8);

        int entry = highByte.getBit(7 - x % 8) << 1 | lowByte.getBit(7 - x % 8);
        bgTilesFrame.setPixel(x, y, entry);
      }
    }

    for (int x = 0; x < 0x80; x++) {
      for (int y = 0; y < 0x80; y++) {
        int number = (y / 8).floor() * 0x10 + (x / 8).floor();
        int highByte = bus.ppuRead(0x1000 + number * 16 + y % 8 + 8);
        int lowByte = bus.ppuRead(0x1000 + number * 16 + y % 8);

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
    bus.cpu.powerOn();
    bus.ppu.powerOn();

    _renderTiles();
    _frameLoop();
  }

  reset() {
    bus.cpu.reset();
    bus.ppu.reset();
    bus.cpuWorkRAM.clear();
    bus.ppuVideoRAM.clear();
    bus.ppuPalettes.clear();
  }
}
