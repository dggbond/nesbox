import "package:flutter_nes/flutter_nes.dart";
import "package:flutter_nes/util/util.dart";
import "package:test/test.dart";

import "dart:io";

int simulateCpuAddressing(CPU cpu) {
  int beginRegPC = cpu.regPC; // used for restore initial regPC
  int beginCycles = cpu.cycles;
  int opcode = cpu.read(cpu.regPC++);

  cpu.op = CPU_OPS[opcode];

  if (cpu.op == null) {
    throw 'Unknow opcode: ${opcode.toHex()}';
  }

  cpu.op.mode.call(cpu); // get the address and fetched on cpu.
  cpu.regPC = beginRegPC;
  cpu.cycles = beginCycles;

  return opcode;
}

void main() {
  test("cpu test", () async {
    final testlogs = File("testfiles/nestest.txt").readAsLinesSync();

    final emulator = new NesEmulator();
    final cpu = emulator.cpu;
    final ppu = emulator.ppu;

    emulator.loadGame(File("testfiles/nestest.nes").readAsBytesSync());
    emulator.reset();
    emulator.step(); // consume the cycles that reset created.
    emulator.cpu.regPC = 0xc000;

    for (int index = 0;; index++) {
      if (index > testlogs.length - 1) {
        // test finished;
        return;
      }

      int opcode = simulateCpuAddressing(cpu);

      String b1 = cpu.byte1?.toHex() ?? '';
      String b2 = cpu.byte2?.toHex() ?? '';
      String fetched = cpu.fetched?.toHex() ?? '';

      String opname = cpu.op.abbr;

      String actualLog = cpu.regPC.toHex(4) + '  ${opcode.toHex()} ' + '${b1} ${b2}'.padRight(5, ' ');
      actualLog += '${opname.padLeft(5, ' ')} ADDRESS' +
          'A:${cpu.regA.toHex()} ' +
          'X:${cpu.regX.toHex()} ' +
          'Y:${cpu.regY.toHex()} ' +
          'P:${cpu.regPS.toHex()} ' +
          'SP:${cpu.regSP.toHex()} ' +
          'PPU:${ppu.scanline.toString().padLeft(3, " ")},${ppu.cycle.toString().padLeft(3, " ")} ' +
          'CYC:${cpu.totalCycles}';

      if (opcode == 0x4c || opcode == 0x20) {
        actualLog = actualLog.replaceFirst('ADDRESS', '\$${cpu.address.toHex(4)}'.padRight(28, ' '));
      }

      switch (cpu.op.mode) {
        case ZeroPage:
          actualLog = actualLog.replaceFirst('ADDRESS', '\$${cpu.address.toHex()} = $fetched'.padRight(28, ' '));
          break;

        case ZeroPageX:
          actualLog =
              actualLog.replaceFirst('ADDRESS', '\$$b1,X @ ${cpu.address.toHex()} = $fetched'.padRight(28, ' '));
          break;

        case ZeroPageY:
          actualLog =
              actualLog.replaceFirst('ADDRESS', '\$$b1,Y @ ${cpu.address.toHex()} = $fetched'.padRight(28, ' '));
          break;

        case Absolute:
          actualLog = actualLog.replaceFirst('ADDRESS', '\$${cpu.address.toHex(4)} = $fetched'.padRight(28, ' '));
          break;

        case AbsoluteX:
          actualLog = actualLog.replaceFirst('ADDRESS',
              '\$${(cpu.byte2 << 8 | cpu.byte1).toHex(4)},X @ ${cpu.address.toHex(4)} = $fetched'.padRight(28, ' '));
          break;

        case AbsoluteY:
          actualLog = actualLog.replaceFirst('ADDRESS',
              '\$${(cpu.byte2 << 8 | cpu.byte1).toHex(4)},Y @ ${cpu.address.toHex(4)} = $fetched'.padRight(28, ' '));
          break;

        case Indirect:
          actualLog = actualLog.replaceFirst(
              'ADDRESS', '(\$${(cpu.byte2 << 8 | cpu.byte1).toHex(4)}) = ${cpu.address.toHex(4)}'.padRight(28, ' '));
          break;

        case Implied:
          actualLog = actualLog.replaceFirst('ADDRESS', ' '.padRight(28, ' '));
          break;
        case Accumulator:
          actualLog = actualLog.replaceFirst('ADDRESS', 'A'.padRight(28, ' '));
          break;

        case Immediate:
          actualLog = actualLog.replaceFirst('ADDRESS', '#\$$b1'.padRight(28, ' '));
          break;

        case Relative:
          actualLog = actualLog.replaceFirst('ADDRESS', '\$${cpu.address.toHex(4)}'.padRight(28, ' '));
          break;

        case IndexedIndirect:
          actualLog = actualLog.replaceFirst(
              'ADDRESS',
              '(\$$b1,X) @ ${((cpu.byte1 + cpu.regX) & 0xff).toHex()} = ${cpu.address.toHex(4)} = $fetched'
                  .padRight(28, ' '));
          break;

        case IndirectIndexed:
          actualLog = actualLog.replaceFirst(
              'ADDRESS',
              '(\$$b1),Y = ${(cpu.address - cpu.regY).toHex(4)} @ ${cpu.address.toHex(4)} = $fetched'
                  .padRight(28, ' '));
          break;
      }

      expect(actualLog, testlogs[index], reason: "at line:${index + 1}");

      emulator.step();
    }
  });
}
