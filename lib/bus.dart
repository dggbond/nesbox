import 'cartridge.dart';
import 'cpu.dart';
import 'ppu.dart';
import 'memory.dart';

// bus is used to communiate between hardwares
class BUS {
  BUS() {
    cpu.bus = this;
    ppu.bus = this;
  }

  CPU cpu = CPU();
  PPU ppu = PPU();
  Memory cpuWorkRAM = Memory(0x800);

  // In most case PPU only use 2kb RAM and mirroring the name tables
  // but when four-screen mirroring it will use an additional 2kb RAM.
  // In this emulator, i ignore four-screen case, so i just need 2kb RAM.
  Memory ppuVideoRAM0 = Memory(0x400);
  Memory ppuVideoRAM1 = Memory(0x400);
  Memory ppuPalettes = Memory(0x20);
  Cardtridge cardtridge = Cardtridge();
}
