library flutter_nes.bus;

import 'dart:typed_data';

import 'cpu.dart';
import 'ppu.dart';
import 'apu.dart';
import 'cartridge.dart';

// bus is used to communiate between hardwares
class BUS {
  BUS() {
    cpu.bus = this;
    ppu.bus = this;
    apu.bus = this;
  }

  CPU cpu = CPU();
  PPU ppu = PPU();
  APU apu = APU();
  Cardtridge card = Cardtridge();

  Uint8List cpuWorkRAM;

  // In most case PPU only use 2kb RAM and mirroring the name tables
  // but when four-screen mirroring it will use an additional 2kb RAM.
  Uint8List ppuVideoRAM;

  Uint8List ppuPalettes;

  reset() {
    cpuWorkRAM = Uint8List(0x800);
    ppuPalettes = Uint8List(0x20);
    ppuVideoRAM = card.mirroring == Mirroring.FourScreen ? Uint8List(0x1000) : Uint8List(0x800);
  }
}
