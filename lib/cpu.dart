library nesbox.cpu;

import 'bus.dart';
import 'util/int_extension.dart';

part 'cpu_address_mode.dart';
part 'cpu_instruction.dart';
part 'cpu_op.dart';

enum CpuInterrupt {
  Nmi,
  Irq,
  Reset,
}

// emualtor for 6502 CPU
class CPU {
  CPU(this.bus);

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

  late Op op; // the executing op
  int dataAddress = 0x00; // the address after address mode.
  CpuInterrupt? interrupt;

  // stack works top-down, see NESDoc page 12.
  pushStack(int value) => write(0x100 + regSP--, value & 0xff);

  int popStack() => read(0x100 + ++regSP) & 0xff;

  pushStack16Bit(int value) {
    pushStack(value >> 8);
    pushStack(value & 0xff);
  }

  int popStack16Bit() => popStack() | (popStack() << 8);

  int read16Bit(int address) => read(address + 1) << 8 | read(address);
  int read16BitUncrossPage(int address) {
    int nextAddress = address & 0xff00 | ((address + 1) % 0x100);

    return read(nextAddress) << 8 | read(address);
  }

  int clock() {
    if (cycles == 0) {
      handleInterrupt();

      final opcode = read(regPC);
      final opArgs = OP_ARGS_TABLE[opcode];

      if (opArgs == null) {
        throw "unknow opcode ${opcode.toHex()}";
      }

      op = Op(opcode, opArgs);

      cycles = op.cycles;

      // addressing
      final result = op.mode.call(this);

      dataAddress = result.address;
      regPC += result.pcStepSize;

      if (result.pageCrossed && op.increaseCycleWhenCrossPage) cycles++;

      // run instruction
      op.instruction.call(this);
    }

    cycles--;
    totalCycles++;

    return 1;
  }

  handleInterrupt() {
    switch (interrupt) {
      case CpuInterrupt.Nmi:
        nmi();
        break;
      case CpuInterrupt.Irq:
        irq();
        break;

      case CpuInterrupt.Reset:
        reset();
        break;

      default:
        return;
    }

    interrupt = null;
  }

  nmi() {
    pushStack16Bit(regPC);
    pushStack(regPS & 0x30);

    regPC = read16Bit(0xfffa);

    // Set the interrupt disable flag to prevent further interrupts.
    fInterruptDisable = 1;

    cycles = 7;
  }

  irq() {
    // IRQ is ignored when interrupt disable flag is set.
    if (fInterruptDisable == 1) {
      return;
    }

    pushStack16Bit(regPC);
    pushStack(regPS);

    fInterruptDisable = 1;

    regPC = read16Bit(0xfffe);

    cycles = 7;
  }

  reset() {
    regSP = 0xfd;
    regPC = read16Bit(0xfffc);
    regPS = 0x24;

    cycles = 7;
  }

  int read(int address) {
    address &= 0xffff;

    // [0x0000, 0x0800] is RAM, [0x0800, 0x02000] is mirrors
    if (address < 0x2000) return bus.cpuWorkRAM[address % 0x800];

    if (address < 0x4000) return bus.ppu.readRegister(0x2000 + address % 0x08);

    if (address < 0x4020) return bus.apu.readRegister(address);

    // Expansion ROM
    if (address < 0x6000) return 0;

    // SRAM
    if (address < 0x8000) return bus.card.read(address);

    // PRG ROM
    return bus.card.read(address);
  }

  void write(int address, int value) {
    address &= 0xffff;
    value &= 0xff;

    // write work RAM & mirrors
    if (address < 0x2000) {
      bus.cpuWorkRAM[address % 0x800] = value;
      return;
    }

    // write ppu registers
    if (address < 0x4000 || address == 0x4014) {
      bus.ppu.writeRegister(0x2000 + address % 0x08, value);
      return;
    }

    // APU and joypad registers;
    if (address < 0x4020) {
      bus.apu.writeRegister(address, value);
      return;
    }

    // Expansion ROM
    if (address < 0x6000) return;

    if (address < 0x8000) {
      if (bus.card.battery) {
        bus.card.sRAM[address - 0x6000] = value;
      }
      return;
    }

    // PRG ROM
    bus.card.write(address, value);
  }
}
