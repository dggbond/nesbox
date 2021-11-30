import 'cpu_instructions.dart';
import 'bus.dart';
import 'util/number.dart';

// emualtor for 6502 CPU
class CPU {
  CPU();

  BUS bus;

  // this is registers
  // see https://en.wikipedia.org/wiki/MOS_Technology_6502#Registers
  int regPC; // Program Counter, the only 16-bit register, others are 8-bit
  int regS; // Stack Pointer register, 8-bit
  int regA; // Accumulator register, 8-bit
  int regX; // Index register, used for indexed addressing mode, 8-bit
  int regY; // Index register, 8-bit

  // Processor Status register, 8-bit
  int get regPS =>
      fCarry |
      fZero << 1 |
      fInterruptDisable << 2 |
      fDecimalMode << 3 |
      fBreakCommand << 4 |
      fOverflow << 6 |
      fNegative << 7;

  set regPS(int value) {
    fCarry = value & 0x1;
    fZero = value >> 1 & 0x1;
    fInterruptDisable = value >> 2 & 0x1;
    fDecimalMode = value >> 3 & 0x1;
    fBreakCommand = value >> 4 & 0x1;
    fOverflow = value >> 6 & 0x1;
    fNegative = value >> 7 & 0x1;
  }

  int fCarry;
  int fZero;
  int fInterruptDisable;
  int fDecimalMode;
  int fBreakCommand;
  int fOverflow;
  int fNegative;

  Interrupt interrupt;

  int cycle;

  // execute one instruction
  int emulate(Op op) {
    int cycles = op.cycles;

    int addr;
    switch (op.addrMode) {
      case AddrMode.ZeroPage:
        addr = bus.cpuRead(regPC + 1) % 0xff;
        break;

      case AddrMode.ZeroPageX:
        addr = (bus.cpuRead(regPC + 1) + regX) % 0xff;
        break;

      case AddrMode.ZeroPageY:
        addr = (bus.cpuRead(regPC + 1) + regY) % 0xff;
        break;

      case AddrMode.Absolute:
        addr = bus.cpuRead16Bit(regPC + 1);
        break;

      case AddrMode.AbsoluteX:
        addr = bus.cpuRead16Bit(regPC + 1) + regX;

        if (isPageCrossed(addr, addr - regX)) cycles++;
        break;

      case AddrMode.AbsoluteY:
        addr = bus.cpuRead16Bit(regPC + 1) + regY;

        if (isPageCrossed(addr, addr - regY)) cycles++;
        break;

      case AddrMode.Indirect:
        addr = bus.cpuRead16Bit(bus.cpuRead16Bit(regPC + 1));
        break;

      // these addressing mode not need to access memory
      case AddrMode.Implied:
      case AddrMode.Accumulator:
        break;

      case AddrMode.Immediate:
        addr = regPC + 1;
        break;

      case AddrMode.Relative:
        int offset = bus.cpuRead(regPC + 1);
        // offset is a signed integer
        addr = offset >= 0x80 ? offset - 0x100 : offset;
        break;

      case AddrMode.IndexedIndirect:
        addr = bus.cpuRead16Bit(bus.cpuRead((regPC + 1 + regX) % 0xff));
        break;

      case AddrMode.IndirectIndexed:
        addr = bus.cpuRead16Bit(bus.cpuRead(regPC + 1)) + regY;

        if (isPageCrossed(addr, addr - regY)) cycles++;
        break;
    }

    // update PC register
    regPC += op.bytes;

    switch (op.instr) {
      case Instr.ADC:
        int M = bus.cpuRead(addr);
        int result = regA + M + fCarry;

        // overflow is basically negative + negative = positive
        // postive + positive = negative
        int overflow = (result ^ regA) & (result ^ M) & 0x80;

        fCarry = result > 0xff ? 1 : 0;
        fOverflow = overflow >> 7;
        fZero = result.getZeroBit();
        fNegative = result.getNegativeBit();

        regA = result & 0xff;
        break;

      case Instr.AND:
        regA &= bus.cpuRead(addr);

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        break;

      case Instr.ASL:
        int M = op.addrMode == AddrMode.Accumulator ? regA : bus.cpuRead(addr);
        int result = (M << 1) & 0xff;

        if (op.addrMode == AddrMode.Accumulator) {
          regA = result;
        } else {
          bus.cpuWrite(addr, result);
        }

        fCarry = M.getBit(7);
        fZero = result.getZeroBit();
        fNegative = result.getNegativeBit();
        break;

      case Instr.BCC:
        if (fCarry == 0) {
          regPC += addr;
          cycles += isPageCrossed(regPC, regPC - addr) ? 2 : 1;
        }

        break;

      case Instr.BCS:
        if (fCarry == 1) {
          regPC += addr;
          cycles += isPageCrossed(regPC, regPC - addr) ? 2 : 1;
        }
        break;

      case Instr.BEQ:
        if (fZero == 1) {
          regPC += addr;
          cycles += isPageCrossed(regPC, regPC - addr) ? 2 : 1;
        }
        break;

      case Instr.BIT:
        int M = bus.cpuRead(addr);
        int test = M & regA;

        fZero = test.getZeroBit();
        fOverflow = M.getBit(6);
        fNegative = M.getNegativeBit();
        break;

      case Instr.BMI:
        if (fNegative == 1) {
          regPC += addr;
          cycles += isPageCrossed(regPC, regPC - addr) ? 2 : 1;
        }
        break;

      case Instr.BNE:
        if (fZero == 0) {
          regPC += addr;
          cycles += isPageCrossed(regPC, regPC - addr) ? 2 : 1;
        }
        break;

      case Instr.BPL:
        if (fNegative == 0) {
          regPC += addr;
          cycles += isPageCrossed(regPC, regPC - addr) ? 2 : 1;
        }
        break;

      case Instr.BRK:
        _pushStack16Bit(regPC + 1);
        _pushStack(regPS);

        fInterruptDisable = 1;
        fBreakCommand = 1;

        regPC = bus.cpuRead16Bit(0xfffe);
        break;

      case Instr.BVC:
        if (fOverflow == 0) {
          regPC += addr;
          cycles += 1;
        }
        break;

      case Instr.BVS:
        if (fOverflow == 1) {
          regPC += addr;
          cycles += isPageCrossed(regPC, regPC - addr) ? 2 : 1;
        }
        break;

      case Instr.CLC:
        fCarry = 0;
        break;

      case Instr.CLD:
        fDecimalMode = 0;
        break;

      case Instr.CLI:
        fInterruptDisable = 0;
        break;

      case Instr.CLV:
        fOverflow = 0;
        break;

      case Instr.CMP:
        int result = regA - bus.cpuRead(addr);

        fCarry = result >= 0 ? 1 : 0;
        fZero = result.getZeroBit();
        fNegative = result.getNegativeBit();
        break;

      case Instr.CPX:
        int result = regX - bus.cpuRead(addr);

        fCarry = result >= 0 ? 1 : 0;
        fZero = result.getZeroBit();
        fNegative = result.getNegativeBit();
        break;

      case Instr.CPY:
        int result = regY - bus.cpuRead(addr);

        fCarry = result >= 0 ? 1 : 0;
        fZero = result.getZeroBit();
        fNegative = result.getNegativeBit();
        break;

      case Instr.DEC:
        int M = bus.cpuRead(addr) - 1;
        bus.cpuWrite(addr, M & 0xff);

        fZero = M.getZeroBit();
        fNegative = M.getNegativeBit();
        break;

      case Instr.DEX:
        regX = (regX - 1) & 0xff;

        fZero = regX.getZeroBit();
        fNegative = regX.getNegativeBit();
        break;

      case Instr.DEY:
        regY = (regY - 1) & 0xff;

        fZero = regY.getZeroBit();
        fNegative = regY.getNegativeBit();
        break;

      case Instr.EOR:
        regA ^= bus.cpuRead(addr);

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        break;

      case Instr.INC:
        int M = bus.cpuRead(addr) + 1;
        bus.cpuWrite(addr, M & 0xff);

        fZero = M.getZeroBit();
        fNegative = M.getNegativeBit();
        break;

      case Instr.INX:
        regX = (regX + 1) & 0xff;

        fZero = regX.getZeroBit();
        fNegative = regX.getNegativeBit();
        break;

      case Instr.INY:
        regY = (regY + 1) & 0xff;

        fZero = regY.getZeroBit();
        fNegative = regY.getNegativeBit();
        break;

      case Instr.JMP:
        regPC = addr;
        break;

      case Instr.JSR:
        _pushStack16Bit(regPC - 1);
        regPC = addr;
        break;

      case Instr.LDA:
        regA = bus.cpuRead(addr);

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        break;

      case Instr.LDX:
        regX = bus.cpuRead(addr);

        fZero = regX.getZeroBit();
        fNegative = regX.getNegativeBit();
        break;

      case Instr.LDY:
        regY = bus.cpuRead(addr);

        fZero = regY.getZeroBit();
        fNegative = regY.getNegativeBit();
        break;

      case Instr.LSR:
        int M = op.addrMode == AddrMode.Accumulator ? regA : bus.cpuRead(addr);
        int result = (M >> 1) & 0xff;

        if (op.addrMode == AddrMode.Accumulator) {
          regA = result;
        } else {
          bus.cpuWrite(addr, result);
        }

        fCarry = M.getBit(7);
        fZero = result.getZeroBit();
        fNegative = result.getNegativeBit();
        break;

      // NOPs
      case Instr.NOP:
      case Instr.SKB:
      case Instr.IGN:
        break;

      case Instr.ORA:
        regA |= bus.cpuRead(addr);

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        break;

      case Instr.PHA:
        _pushStack(regA);
        break;

      case Instr.PHP:
        _pushStack(regPS);
        break;

      case Instr.PLA:
        regA = _popStack();

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        break;

      case Instr.PLP:
        regPS = _popStack();
        break;

      case Instr.ROL:
        int M = op.addrMode == AddrMode.Accumulator ? regA : bus.cpuRead(addr);
        int result = (M << 1).setBit(0, fCarry);

        if (op.addrMode == AddrMode.Accumulator) {
          regA = result;
          fZero = regA.getZeroBit();
        } else {
          bus.cpuWrite(addr, result);
        }

        fCarry = M.getBit(7);
        fNegative = result.getNegativeBit();
        break;

      case Instr.ROR:
        int M = op.addrMode == AddrMode.Accumulator ? regA : bus.cpuRead(addr);
        int result = (M >> 1).setBit(7, fCarry);

        if (op.addrMode == AddrMode.Accumulator) {
          regA = result;
          fZero = regA.getZeroBit();
        } else {
          bus.cpuWrite(addr, result);
        }

        fCarry = M.getBit(0);
        fNegative = M.getNegativeBit();
        break;

      case Instr.RTI:
        regPS = _popStack();
        regPC = _popStack16Bit();

        fInterruptDisable = 0;
        break;

      case Instr.RTS:
        regPC = _popStack16Bit() + 1;
        break;

      case Instr.SBC:
        int M = bus.cpuRead(addr);
        int result = regA - M - (1 - fCarry);

        int overflow = (result ^ regA) & (result ^ M) & 0x80;

        fCarry = result > 0xff ? 0 : 1;
        fZero = result.getZeroBit();
        fOverflow = overflow >> 7;
        fNegative = result.getNegativeBit();

        regA = result & 0xff;
        break;

      case Instr.SEC:
        fCarry = 1;
        break;

      case Instr.SED:
        fDecimalMode = 1;
        break;

      case Instr.SEI:
        fInterruptDisable = 1;
        break;

      case Instr.STA:
        bus.cpuWrite(addr, regA);
        break;

      case Instr.STX:
        bus.cpuWrite(addr, regX);
        break;

      case Instr.STY:
        bus.cpuWrite(addr, regY);
        break;

      case Instr.TAX:
        regX = regA;

        fZero = regX.getZeroBit();
        fNegative = regX.getNegativeBit();
        break;

      case Instr.TAY:
        regY = regA;

        fZero = regY.getZeroBit();
        fNegative = regY.getNegativeBit();
        break;

      case Instr.TSX:
        regX = regS;

        fZero = regX.getZeroBit();
        fNegative = regX.getNegativeBit();
        break;

      case Instr.TXA:
        regA = regX;

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        break;

      case Instr.TXS:
        regS = regX;
        break;

      case Instr.TYA:
        regA = regY;

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        break;

      case Instr.ALR:
        emulate(Op(Instr.AND, AddrMode.Immediate, 0, 0));
        emulate(Op(Instr.LSR, AddrMode.Accumulator, 0, 0));
        break;

      case Instr.ANC:
        regA &= bus.cpuRead(addr);

        fCarry = regA.getBit(7);
        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        break;

      case Instr.ARR:
        emulate(Op(Instr.AND, AddrMode.Immediate, 0, 0));
        emulate(Op(Instr.ROR, AddrMode.Accumulator, 0, 0));
        break;

      case Instr.AXS:
        regX &= regA;

        fCarry = 0;
        fZero = regX.getZeroBit();
        fNegative = regX.getNegativeBit();
        break;

      case Instr.LAX:
        regX = regA = bus.cpuRead(addr);

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        break;

      case Instr.SAX:
        regX &= regA;
        bus.cpuWrite(addr, regX);
        break;

      case Instr.DCP:
        emulate(Op(Instr.DEC, op.addrMode, 0, 0));
        emulate(Op(Instr.CMP, op.addrMode, 0, 0));
        break;

      case Instr.ISC:
        emulate(Op(Instr.INC, op.addrMode, 0, 0));
        emulate(Op(Instr.SBC, op.addrMode, 0, 0));
        break;

      case Instr.RLA:
        emulate(Op(Instr.ROL, op.addrMode, 0, 0));
        emulate(Op(Instr.AND, op.addrMode, 0, 0));
        break;

      case Instr.RRA:
        emulate(Op(Instr.ROR, op.addrMode, 0, 0));
        emulate(Op(Instr.ADC, op.addrMode, 0, 0));
        break;

      case Instr.SLO:
        emulate(Op(Instr.ASL, op.addrMode, 0, 0));
        emulate(Op(Instr.ORA, op.addrMode, 0, 0));
        break;

      case Instr.SRE:
        emulate(Op(Instr.LSR, op.addrMode, 0, 0));
        emulate(Op(Instr.EOR, op.addrMode, 0, 0));
        break;

      default:
        throw ("cpu emulate: ${op.instr} is an unknown instruction.");
    }

    cycles += bus.dmaCycles;
    bus.dmaCycles = 0;

    return cycles;
  }

  int tick() {
    switch (interrupt) {
      case Interrupt.NMI:
        return nmi();
      case Interrupt.IRQ:
        // IRQ is ignored when interrupt disable flag is set.
        if (fInterruptDisable == 1) break;
        return irq();
      case Interrupt.RESET:
        reset();
        return 7;
    }

    int opcode = bus.cpuRead(regPC);

    if (opcode == null) {
      throw ("can't find instruction at: ${regPC.toHex()}");
    }

    Op op = NES_CPU_OPS[opcode];
    if (op == null) {
      throw ("${opcode.toHex(2)} is unknown instruction at rom address ${regPC.toHex()}");
    }

    return emulate(op);
  }

  // CPU power-up state see: https://wiki.nesdev.com/w/index.php/CPU_power_up_state
  void powerOn() {
    regPC = bus.cpuRead16Bit(0xfffc);
    regPS = 0x34;
    regS = 0xfd;
    regA = 0x00;
    regX = 0x00;
    regY = 0x00;
  }
}

extension InterruptHandlers on CPU {
  int nmi() {
    _pushStack16Bit(regPC);
    _pushStack(regPS);

    // Set the interrupt disable flag to prevent further interrupts.
    fInterruptDisable = 1;

    regPC = bus.cpuRead16Bit(0xfffa);
    interrupt = null;

    return 7;
  }

  int irq() {
    interrupt = null;

    _pushStack16Bit(regPC);
    _pushStack(regPS);

    fInterruptDisable = 1;
    fBreakCommand = 0;

    regPC = bus.cpuRead16Bit(0xfffe);

    return 7;
  }

  void reset() {
    regPC = bus.cpuRead16Bit(0xfffc);
    regS = 0xfd;

    fInterruptDisable = 1;
  }
}

extension StackOperators on CPU {
  // stack works top-down, see NESDoc page 12.
  _pushStack(int value) {
    if (regS < 0) {
      throw ("push stack failed. stack pointer ${regS.toHex()} is overflow stack area.");
    }

    bus.cpuWrite(0x100 + regS--, value);
  }

  int _popStack() {
    if (regS > 0xff) {
      throw ("pop stack failed. stack pointer ${regS.toHex()} is at the start of stack area.");
    }

    return bus.cpuRead(0x100 + ++regS);
  }

  void _pushStack16Bit(int value) {
    _pushStack(value >> 8 & 0xff);
    _pushStack(value & 0xff);
  }

  int _popStack16Bit() {
    return _popStack() | (_popStack() << 8);
  }
}
