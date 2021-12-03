import "package:flutter_nes/flutter_nes.dart";
import "package:flutter_nes/util/util.dart";
import "package:test/test.dart";

import "dart:io";

void main() {
  test("cpu test", () async {
    final emulator = new NesEmulator();
    CPU cpu = emulator.cpu;
    PPU ppu = emulator.ppu;

    emulator.loadGame(File("roms/nestest.nes").readAsBytesSync());
    emulator.powerOn();
    emulator.cpu.regPC = 0xc000;
    emulator.cpu.regPS = 0x24;

    while (true) {
      String msg = cpu.regPC.toHex();

      emulator.step();

      msg += ' ${cpu.op.instruction.name()} ' +
          'A: ${cpu.regA.toHex()} ' +
          'X: ${cpu.regX.toHex()} ' +
          'Y: ${cpu.regY.toHex()} ' +
          'P: ${cpu.regPS.toHex()} ' +
          'SP: ${cpu.regSP.toHex()} ' +
          'PPU: ${ppu.scanline}, ${ppu.cycle} ' +
          'CYC: ${cpu.totalCycles}';

      log(msg);
    }
  });
}
