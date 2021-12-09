library flutter_nes.cpu;

import 'package:flutter_nes/bus.dart';

import 'op.dart';
import 'interrupt.dart' as cpu_interrupt;

export 'op.dart';
export 'address_mode.dart';
export 'instruction.dart';

// emualtor for 6502 CPU
class CPU {
  BUS bus;

  // this is registers
  // see https://en.wikipedia.org/wiki/MOS_Technology_6502#Registers
  int regPC = 0x0000; // Program Counter, the only 16-bit register, others are 8-bit
  int regSP = 0x00; // Stack Pointer register, 8-bit
  int regA = 0x00; // Accumulator register, 8-bit
  int regX = 0x00; // Index register, used for indexed addressing mode, 8-bit
  int regY = 0x00; // Index register, 8-bit

  // Processor Status register, 8-bit
  int get regPS =>
      fCarry |
      fZero << 1 |
      fInterruptDisable << 2 |
      fDecimalMode << 3 |
      fBreakCommand << 4 |
      fUnused << 5 |
      fOverflow << 6 |
      fNegative << 7;

  set regPS(int value) {
    fCarry = value & 0x1;
    fZero = value >> 1 & 0x1;
    fInterruptDisable = value >> 2 & 0x1;
    fDecimalMode = value >> 3 & 0x1;
    fBreakCommand = value >> 4 & 0x1;
    fUnused = value >> 5 & 0x1;
    fOverflow = value >> 6 & 0x1;
    fNegative = value >> 7 & 0x1;
  }

  int fCarry = 0;
  int fZero = 0;
  int fInterruptDisable = 0;
  int fDecimalMode = 0;
  int fBreakCommand = 0;
  int fUnused = 0;
  int fOverflow = 0;
  int fNegative = 0;

  int cycles = 0;
  int totalCycles = 0;

  Op op; // the executing op
  Function interrupt;
  int address = 0x00; // the address after address mode.

  int fetch() => read(address);

  // stack works top-down, see NESDoc page 12.
  pushStack(int value) => write(0x100 + regSP--, value & 0xff);

  int popStack() => read(0x100 + ++regSP) & 0xff;

  pushStack16Bit(int value) {
    pushStack(value >> 8);
    pushStack(value & 0xff);
  }

  int popStack16Bit() => popStack() | (popStack() << 8);

  int clock() {
    if (cycles == 0) {
      interrupt?.call(this);
      interrupt = null;

      op = OP_TABLE[read(regPC++)];
      cycles = op.cycles;

      op.mode.call(this);
      op.instruction.call(this);
    }

    cycles--;
    totalCycles++;

    return 1;
  }

  reset() => cpu_interrupt.reset(this);

  int read(int addr) => bus.cpuRead(addr) & 0xff;
  int read16Bit(int address) => read(address + 1) << 8 | read(address);
  int read16BitUncrossPage(int address) {
    int nextAddress = address & 0xff00 | ((address + 1) % 0x100);

    return read(nextAddress) << 8 | read(address);
  }

  void write(int addr, int value) => bus.cpuWrite(addr, value);
}
