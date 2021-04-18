library flutter_nes;

import "dart:typed_data";

import 'package:flutter_nes/cartridge.dart';
import "package:flutter_nes/cpu.dart";
import "package:flutter_nes/ppu.dart";
import "package:flutter_nes/bus.dart";
import "package:flutter_nes/memory.dart";

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

  // load nes rom data
  loadGame(Uint8List data) {
    cardtridge.loadGame(data);
  }

  tick() {
    int cycles = cpu.tick();

    if (cpu.dmaCycles != 0) {
      cycles = cpu.dmaCycles;
    }

    for (int i = cycles * 3; i >= 0; i--) {
      ppu.tick();
    }

    // clear DMA cycles;
    cpu.dmaCycles = 0;

    Future.delayed(Duration(microseconds: (CPU.MICRO_SEC_PER_CYCLE * cycles).round()), tick)
      .catchError((err) {
        print(err);
      });
  }

  powerOn() {
    cpu.powerOn();
    ppu.powerOn();

    tick();
  }

  reset() {
    cpu.reset();
    ppu.reset();
    cpuWorkRAM.reset();
    ppuVideoRAM.reset();
    ppuPalettes.reset();
  }
}
