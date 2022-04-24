import "package:test/test.dart";

import 'package:nesbox/cpu.dart';
import "package:nesbox/nesbox.dart";
import "package:nesbox/util/util.dart";
import "./cpu_test.dart";

import "dart:io";

void main() {
  test("cpu test", () async {
    final box = new NesBox();
    final cpu = box.cpu;
    final ppu = box.ppu;

    box.loadGame(File("roms/Super_mario_brothers.nes").readAsBytesSync());
    box.reset();
    box.stepInsruction();

    while (true) {
      int opcode = simulateCpuAddressing(cpu);

      String cpuLog = cpu.regPC.toHex(4) + '  ${opcode.toHex()} data';
      cpuLog += '${cpu.op.abbr.padLeft(5, ' ')} ADDRESS' +
          'A:${cpu.regA.toHex()} ' +
          'X:${cpu.regX.toHex()} ' +
          'Y:${cpu.regY.toHex()} ' +
          'P:${cpu.regPS.toHex()} ' +
          'SP:${cpu.regSP.toHex()} ' +
          'PPU:${ppu.scanline.toString().padLeft(3, " ")},${ppu.cycle.toString().padLeft(3, " ")} ' +
          'CYC:${cpu.totalCycles}';

      if (opcode == 0x4c || opcode == 0x20) {
        cpuLog = cpuLog.replaceFirst('ADDRESS', '\$${cpu.dataAddress.toHex(4)}'.padRight(28, ' '));
      }

      String b1 = cpu.byte1!.toHex(2);
      String b2 = cpu.byte2!.toHex(2);

      String data = cpu.byte1 != null ? b1 : '';
      if (cpu.byte2 != null) {
        data += ' $b2';
      }
      cpuLog = cpuLog.replaceFirst('data', data.padRight(5, ' '));

      switch (cpu.op.mode) {
        case ZeroPage:
          cpuLog = cpuLog.replaceFirst('ADDRESS', '\$${cpu.dataAddress.toHex()}'.padRight(28, ' '));
          break;

        case ZeroPageX:
          cpuLog = cpuLog.replaceFirst('ADDRESS', '\$$b1,X @ ${cpu.dataAddress.toHex()}'.padRight(28, ' '));
          break;

        case ZeroPageY:
          cpuLog = cpuLog.replaceFirst('ADDRESS', '\$$b1,Y @ ${cpu.dataAddress.toHex()}'.padRight(28, ' '));
          break;

        case Absolute:
          cpuLog = cpuLog.replaceFirst('ADDRESS', '\$${cpu.dataAddress.toHex(4)}'.padRight(28, ' '));
          break;

        case AbsoluteX:
          cpuLog = cpuLog.replaceFirst('ADDRESS',
              '\$${(cpu.byte2! << 8 | cpu.byte1!).toHex(4)},X @ ${cpu.dataAddress.toHex(4)}'.padRight(28, ' '));
          break;

        case AbsoluteY:
          cpuLog = cpuLog.replaceFirst('ADDRESS',
              '\$${(cpu.byte2! << 8 | cpu.byte1!).toHex(4)},Y @ ${cpu.dataAddress.toHex(4)}'.padRight(28, ' '));
          break;

        case Indirect:
          cpuLog = cpuLog.replaceFirst('ADDRESS',
              '(\$${(cpu.byte2! << 8 | cpu.byte1!).toHex(4)}) = ${cpu.dataAddress.toHex(4)}'.padRight(28, ' '));
          break;

        case Implied:
          cpuLog = cpuLog.replaceFirst('ADDRESS', ' '.padRight(28, ' '));
          break;
        case Accumulator:
          cpuLog = cpuLog.replaceFirst('ADDRESS', 'A'.padRight(28, ' '));
          break;

        case Immediate:
          cpuLog = cpuLog.replaceFirst('ADDRESS', '#\$$b1'.padRight(28, ' '));
          break;

        case Relative:
          cpuLog = cpuLog.replaceFirst('ADDRESS', '\$${cpu.dataAddress.toHex(4)}'.padRight(28, ' '));
          break;

        case IndexedIndirect:
          cpuLog = cpuLog.replaceFirst(
              'ADDRESS',
              '(\$$b1,X) @ ${((cpu.byte1! + cpu.regX) & 0xff).toHex()} = ${cpu.dataAddress.toHex(4)}'
                  .padRight(28, ' '));
          break;

        case IndirectIndexed:
          cpuLog = cpuLog.replaceFirst('ADDRESS',
              '(\$$b1),Y = ${(cpu.dataAddress - cpu.regY).toHex(4)} @ ${cpu.dataAddress.toHex(4)}'.padRight(28, ' '));
          break;
      }

      box.stepInsruction();
    }
  });
}
