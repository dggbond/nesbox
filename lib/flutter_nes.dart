library flutter_nes;

import "dart:typed_data";

import "package:flutter_nes/cpu.dart";
import "package:flutter_nes/ppu.dart";
import "package:flutter_nes/rom.dart";
import "package:flutter_nes/bus.dart";

class NesEmulator {
  NesEmulator() {
    cpu = NesCpu(this._bus);
    ppu = NesPpu(this._bus);

    _bus.cpu = cpu;
  }

  NesBus _bus = NesBus();

  NesCpu cpu;
  NesPpu ppu;
  NesRom rom;

  // load nes rom data
  loadROM(Uint8List data) async {
    _bus.rom = rom = NesRom(data);
  }

  powerOn() {
    cpu.powerOn();
    ppu.powerOn();
  }
}
