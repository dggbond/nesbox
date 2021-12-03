import 'cpu_instructions.dart';
import 'bus.dart';

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
  int absAddr = 0x00;
  int relAddr = 0x00;

  // stack works top-down, see NESDoc page 12.
  pushStack(int value) {
    write(0x100 + regSP, value);
    regSP--;
  }

  popStack() {
    regSP++;
    return read(0x100 + regSP);
  }

  pushStack16Bit(int value) {
    pushStack(value >> 8 & 0xff);
    pushStack(value & 0xff);
  }

  popStack16Bit() {
    return popStack() | (popStack() << 8);
  }

  int fetch() {
    if (op.mode == Accumulator) {
      return regA;
    } else if (op.mode != Implied) {
      return read(absAddr);
    }
  }

  branchSuccess() {
    absAddr = regPC + relAddr;

    cycles += isPageCrossed(absAddr, regPC) ? 2 : 1;

    regPC = absAddr;
  }

  nmi() {
    pushStack16Bit(regPC);

    // Set the interrupt disable flag to prevent further interrupts.
    fInterruptDisable = 1;
    fBreakCommand = 0;

    pushStack(regPS);
    regPC = read16Bit(0xfffa);

    cycles = 7;
  }

  irq() {
    // IRQ is ignored when interrupt disable flag is set.
    if (fInterruptDisable == 1) return;

    pushStack16Bit(regPC);

    fInterruptDisable = 1;
    fBreakCommand = 0;

    pushStack(regPS);
    regPC = read16Bit(0xfffe);

    cycles = 7;
  }

  reset() {
    regA = 0;
    regX = 0;
    regY = 0;
    regSP = 0xfd;
    regPC = read16Bit(0xfffc);

    cycles = 8;
  }

  int clock() {
    if (cycles == 0) {
      op = CPU_OPS[read(regPC++)];

      cycles = op.cycles;

      op.mode.call(this);
      op.instruction.call(this);
    }

    cycles--;
    totalCycles++;

    return 1;
  }

  int read(int addr) => bus.cpuRead(addr);
  int read16Bit(int address) => read(address + 1) << 8 | read(address);

  void write(int addr, int value) => bus.cpuWrite(addr, value);
}
