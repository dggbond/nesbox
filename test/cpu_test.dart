import "package:test/test.dart";
import "package:nesbox/nesbox.dart";
import "package:nesbox/cpu.dart";
import "package:nesbox/util/util.dart";

import "dart:io";

int simulateCpuAddressing(CPU cpu) {
  int beginRegPC = cpu.regPC; // used for restore initial regPC
  int beginCycles = cpu.cycles;
  int opcode = cpu.read(cpu.regPC++);

  cpu.op = OP_TABLE[opcode]!;
  cpu.byte1 = null;
  cpu.byte2 = null;

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

    final box = new NesBox();
    final cpu = box.cpu;
    final ppu = box.ppu;

    box.loadGame(File("testfiles/nestest.nes").readAsBytesSync());
    box.reset();
    box.stepInsruction(); // consume the cycles that reset created.
    box.cpu.regPC = 0xc000;

    for (int index = 0;; index++) {
      if (index > testlogs.length - 1) {
        // test finished;
        return;
      }

      int opcode = simulateCpuAddressing(cpu);

      String actualLog = cpu.regPC.toHex(4) + '  ${opcode.toHex()} ' + 'data';
      actualLog += '${cpu.op.abbr.padLeft(5, ' ')} ADDRESS' +
          'A:${cpu.regA.toHex()} ' +
          'X:${cpu.regX.toHex()} ' +
          'Y:${cpu.regY.toHex()} ' +
          'P:${cpu.regPS.toHex()} ' +
          'SP:${cpu.regSP.toHex()} ' +
          'PPU:${ppu.scanline.toString().padLeft(3, " ")},${ppu.cycle.toString().padLeft(3, " ")} ' +
          'CYC:${cpu.totalCycles}';

      String fetched = cpu.fetch().toHex();

      if (opcode == 0x4c || opcode == 0x20) {
        actualLog = actualLog.replaceFirst('ADDRESS', '\$${cpu.dataAddress.toHex(4)}'.padRight(28, ' '));
      }

      String b1 = cpu.byte1!.toHex(2);
      String b2 = cpu.byte2!.toHex(2);

      String data = cpu.byte1 != null ? b1 : '';
      if (cpu.byte2 != null) {
        data += ' $b2';
      }
      actualLog = actualLog.replaceFirst('data', data.padRight(5, ' '));

      switch (cpu.op.mode) {
        case ZeroPage:
          actualLog = actualLog.replaceFirst('ADDRESS', '\$${cpu.dataAddress.toHex()} = $fetched'.padRight(28, ' '));
          break;

        case ZeroPageX:
          actualLog =
              actualLog.replaceFirst('ADDRESS', '\$$b1,X @ ${cpu.dataAddress.toHex()} = $fetched'.padRight(28, ' '));
          break;

        case ZeroPageY:
          actualLog =
              actualLog.replaceFirst('ADDRESS', '\$$b1,Y @ ${cpu.dataAddress.toHex()} = $fetched'.padRight(28, ' '));
          break;

        case Absolute:
          actualLog = actualLog.replaceFirst('ADDRESS', '\$${cpu.dataAddress.toHex(4)} = $fetched'.padRight(28, ' '));
          break;

        case AbsoluteX:
          actualLog = actualLog.replaceFirst(
              'ADDRESS',
              '\$${(cpu.byte2! << 8 | cpu.byte1!).toHex(4)},X @ ${cpu.dataAddress.toHex(4)} = $fetched'
                  .padRight(28, ' '));
          break;

        case AbsoluteY:
          actualLog = actualLog.replaceFirst(
              'ADDRESS',
              '\$${(cpu.byte2! << 8 | cpu.byte1!).toHex(4)},Y @ ${cpu.dataAddress.toHex(4)} = $fetched'
                  .padRight(28, ' '));
          break;

        case Indirect:
          actualLog = actualLog.replaceFirst('ADDRESS',
              '(\$${(cpu.byte2! << 8 | cpu.byte1!).toHex(4)}) = ${cpu.dataAddress.toHex(4)}'.padRight(28, ' '));
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
          actualLog = actualLog.replaceFirst('ADDRESS', '\$${cpu.dataAddress.toHex(4)}'.padRight(28, ' '));
          break;

        case IndexedIndirect:
          actualLog = actualLog.replaceFirst(
              'ADDRESS',
              '(\$$b1,X) @ ${((cpu.byte1! + cpu.regX) & 0xff).toHex()} = ${cpu.dataAddress.toHex(4)} = $fetched'
                  .padRight(28, ' '));
          break;

        case IndirectIndexed:
          actualLog = actualLog.replaceFirst(
              'ADDRESS',
              '(\$$b1),Y = ${(cpu.dataAddress - cpu.regY).toHex(4)} @ ${cpu.dataAddress.toHex(4)} = $fetched'
                  .padRight(28, ' '));
          break;
      }

      box.stepInsruction();

      expect(actualLog, testlogs[index], reason: "at line:${index + 1}");
    }
  });
}
