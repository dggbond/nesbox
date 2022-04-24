library nesbox.bus;

import 'dart:typed_data';

import 'cpu.dart';
import 'ppu.dart';
import 'apu.dart';
import 'cartridge.dart';

// bus is used to communiate between hardwares
class BUS {
  BUS() {
    cpu = CPU(this);
    ppu = PPU(this);
    apu = APU(this);
  }

  late CPU cpu;
  late PPU ppu;
  late APU apu;

  Cardtridge card = Cardtridge();

  Uint8List cpuWorkRAM = Uint8List(0);

  // In most case PPU only use 2kb RAM and mirroring the name tables
  // but when four-screen mirroring it will use an additional 2kb RAM.
  Uint8List ppuVideoRAM = Uint8List(0);

  Uint8List ppuPalettes = Uint8List(0);

  reset() {
    cpuWorkRAM = Uint8List(0x800);
    ppuPalettes = Uint8List(0x20);
    ppuVideoRAM = card.mirroring == Mirroring.FourScreen ? Uint8List(0x1000) : Uint8List(0x800);
  }
}
