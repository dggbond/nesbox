library flutter_nes;

import "dart:typed_data";

import 'package:flutter_nes/cartridge.dart';
import "package:flutter_nes/cpu.dart";
import "package:flutter_nes/ppu.dart";
import "package:flutter_nes/bus.dart";
import "package:flutter_nes/ram.dart";

class Emulator {
  Emulator() {
    cpu = CPU(bus);
    ppu = PPU(bus);

    bus.cpu = cpu;
    bus.ppu = ppu;
    bus.cpuRAM = cpuWorkRAM;
    bus.ppuRAM = ppuVideoRAM;
    bus.cardtridge = cardtridge;
  }

  BUS bus = BUS();

  CPU cpu;
  PPU ppu;
  RAM cpuWorkRAM = RAM(0x800);
  RAM ppuVideoRAM = RAM(0x800);
  Cardtridge cardtridge = Cardtridge();

  // load nes rom data
  loadGame(Uint8List data) {
    this.cardtridge.loadGame(data);
  }

  powerOn() {
    ppu.powerOn();
    cpu.powerOn();
  }
}
