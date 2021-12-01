import 'cpu_instructions.dart';
import 'bus.dart';
import 'util/util.dart';

export 'cpu_instructions.dart';

// emualtor for 6502 CPU
class CPU {
  CPU();

  BUS bus;

  // this is registers
  // see https://en.wikipedia.org/wiki/MOS_Technology_6502#Registers
  int regPC; // Program Counter, the only 16-bit register, others are 8-bit
  int regSP; // Stack Pointer register, 8-bit
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

  int cycles = 0;

  Op op;
  int absAddr = 0x00;
  int relAddr = 0x00;

  // stack works top-down, see NESDoc page 12.
  _pushStack(int value) => write(0x100 + regSP--, value);
  _popStack() => read(0x100 + ++regSP);

  _pushStack16Bit(int value) {
    _pushStack(value >> 8 & 0xff);
    _pushStack(value & 0xff);
  }

  _popStack16Bit() {
    return _popStack() | (_popStack() << 8);
  }

  nmi() {
    _pushStack16Bit(regPC);

    // Set the interrupt disable flag to prevent further interrupts.
    fInterruptDisable = 1;
    fBreakCommand = 0;

    _pushStack(regPS);
    regPC = read16Bit(0xfffa);

    cycles = 7;
  }

  irq() {
    // IRQ is ignored when interrupt disable flag is set.
    if (fInterruptDisable == 1) return;

    _pushStack16Bit(regPC);

    fInterruptDisable = 1;
    fBreakCommand = 0;

    _pushStack(regPS);
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

  addressing(AddrMode am) {
    switch (am) {
      case AddrMode.ZeroPage:
        absAddr = read(regPC++) & 0xff;
        return 0;

      case AddrMode.ZeroPageX:
        absAddr = (read(regPC++) + regX) & 0xff;
        return 0;

      case AddrMode.ZeroPageY:
        absAddr = (read(regPC++) + regY) & 0xff;
        return 0;

      case AddrMode.Absolute:
        absAddr = read16Bit(regPC);
        regPC += 2;
        return 0;

      case AddrMode.AbsoluteX:
        absAddr = read16Bit(regPC) + regX;
        regPC += 2;

        if (isPageCrossed(absAddr, absAddr - regX)) return 1;
        return 0;

      case AddrMode.AbsoluteY:
        absAddr = read16Bit(regPC) + regY;
        regPC += 2;

        if (isPageCrossed(absAddr, absAddr - regY)) return 1;
        return 0;

      case AddrMode.Indirect:
        absAddr = read16Bit(read16Bit(regPC));
        regPC += 2;
        return 0;

      case AddrMode.Implied:
      case AddrMode.Accumulator:
        return 0;

      case AddrMode.Immediate:
        absAddr = regPC++;
        return 0;

      case AddrMode.Relative:
        // offset is a signed integer
        int offset = read(regPC++);

        relAddr = offset >= 0x80 ? offset | 0xff00 : offset;
        return 0;

      case AddrMode.IndexedIndirect:
        absAddr = read16Bit(read((regPC++ + regX) & 0xff));
        return 0;

      case AddrMode.IndirectIndexed:
        absAddr = read16Bit(read(regPC++)) + regY;

        if (isPageCrossed(absAddr, absAddr - regY)) return 1;
        return 0;
    }

    return 0;
  }

  branchSuccess() {
    cycles++;
    absAddr = regPC + relAddr;

    if (isPageCrossed(absAddr, regPC)) {
      cycles++;
    }

    regPC = absAddr;
  }

  // execute one instruction
  int execute(Instr instr) {
    int fetched;
    if (op.addrMode == AddrMode.Accumulator) {
      fetched = regA;
    } else if (op.addrMode != AddrMode.Implied) {
      fetched = read(absAddr);
    }

    switch (instr) {
      case Instr.ADC:
        int tmp = regA + fetched + fCarry;

        // overflow is basically negative + negative = positive
        // postive + positive = negative
        int overflow = (tmp ^ regA) & (tmp ^ fetched) & 0x80;

        fCarry = tmp > 0xff ? 1 : 0;
        fOverflow = overflow >> 7;
        fZero = tmp.getZeroBit();
        fNegative = tmp.getNegativeBit();

        regA = tmp & 0xff;
        return 0;

      case Instr.AND:
        regA &= fetched;

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        return 0;

      case Instr.ASL:
        int tmp = (fetched << 1) & 0xff;

        if (op.addrMode == AddrMode.Accumulator) {
          regA = tmp;
        } else {
          write(absAddr, tmp);
        }

        fCarry = fetched.getBit(7);
        fZero = tmp.getZeroBit();
        fNegative = tmp.getNegativeBit();
        return 0;

      case Instr.BCC:
        if (fCarry == 0) {
          branchSuccess();
        }
        return 0;

      case Instr.BCS:
        if (fCarry == 1) {
          branchSuccess();
        }
        return 0;

      case Instr.BEQ:
        if (fZero == 1) {
          branchSuccess();
        }
        return 0;

      case Instr.BIT:
        int test = fetched & regA;

        fZero = test.getZeroBit();
        fOverflow = fetched.getBit(6);
        fNegative = fetched.getNegativeBit();
        return 0;

      case Instr.BMI:
        if (fNegative == 1) {
          branchSuccess();
        }
        return 0;

      case Instr.BNE:
        if (fZero == 0) {
          branchSuccess();
        }
        return 0;

      case Instr.BPL:
        if (fNegative == 0) {
          branchSuccess();
        }
        return 0;

      case Instr.BRK:
        _pushStack16Bit(regPC + 1);
        _pushStack(regPS);

        fInterruptDisable = 1;
        fBreakCommand = 1;

        regPC = read16Bit(0xfffe);
        return 0;

      case Instr.BVC:
        if (fOverflow == 0) {
          branchSuccess();
        }
        return 0;

      case Instr.BVS:
        if (fOverflow == 1) {
          branchSuccess();
        }
        return 0;

      case Instr.CLC:
        fCarry = 0;
        return 0;

      case Instr.CLD:
        fDecimalMode = 0;
        return 0;

      case Instr.CLI:
        fInterruptDisable = 0;
        return 0;

      case Instr.CLV:
        fOverflow = 0;
        return 0;

      case Instr.CMP:
        int result = regA - fetched;

        fCarry = result >= 0 ? 1 : 0;
        fZero = result.getZeroBit();
        fNegative = result.getNegativeBit();
        return 0;

      case Instr.CPX:
        int result = regX - fetched;

        fCarry = result >= 0 ? 1 : 0;
        fZero = result.getZeroBit();
        fNegative = result.getNegativeBit();
        return 0;

      case Instr.CPY:
        int result = regY - fetched;

        fCarry = result >= 0 ? 1 : 0;
        fZero = result.getZeroBit();
        fNegative = result.getNegativeBit();
        return 0;

      case Instr.DEC:
        fetched--;
        write(absAddr, fetched & 0xff);

        fZero = fetched.getZeroBit();
        fNegative = fetched.getNegativeBit();
        return 0;

      case Instr.DEX:
        regX = (regX - 1) & 0xff;

        fZero = regX.getZeroBit();
        fNegative = regX.getNegativeBit();
        return 0;

      case Instr.DEY:
        regY = (regY - 1) & 0xff;

        fZero = regY.getZeroBit();
        fNegative = regY.getNegativeBit();
        return 0;

      case Instr.EOR:
        regA ^= fetched;

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        return 0;

      case Instr.INC:
        fetched++;
        write(absAddr, fetched & 0xff);

        fZero = fetched.getZeroBit();
        fNegative = fetched.getNegativeBit();
        return 0;

      case Instr.INX:
        regX = (regX + 1) & 0xff;

        fZero = regX.getZeroBit();
        fNegative = regX.getNegativeBit();
        return 0;

      case Instr.INY:
        regY = (regY + 1) & 0xff;

        fZero = regY.getZeroBit();
        fNegative = regY.getNegativeBit();
        return 0;

      case Instr.JMP:
        regPC = absAddr;
        return 0;

      case Instr.JSR:
        _pushStack16Bit(regPC - 1);
        regPC = absAddr;
        return 0;

      case Instr.LDA:
        regA = fetched;

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        return 0;

      case Instr.LDX:
        regX = fetched;

        fZero = regX.getZeroBit();
        fNegative = regX.getNegativeBit();
        return 0;

      case Instr.LDY:
        regY = fetched;

        fZero = regY.getZeroBit();
        fNegative = regY.getNegativeBit();
        return 0;

      case Instr.LSR:
        int tmp = (fetched >> 1) & 0xff;

        if (op.addrMode == AddrMode.Accumulator) {
          regA = tmp;
        } else {
          write(absAddr, tmp);
        }

        fCarry = fetched.getBit(7);
        fZero = tmp.getZeroBit();
        fNegative = tmp.getNegativeBit();
        return 0;

      // NOPs
      case Instr.NOP:
      case Instr.SKB:
      case Instr.IGN:
        return 0;

      case Instr.ORA:
        regA |= fetched;

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        return 0;

      case Instr.PHA:
        _pushStack(regA);
        return 0;

      case Instr.PHP:
        _pushStack(regPS);
        return 0;

      case Instr.PLA:
        regA = _popStack();

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        return 0;

      case Instr.PLP:
        regPS = _popStack();
        return 0;

      case Instr.ROL:
        int tmp = (fetched << 1).setBit(0, fCarry);

        if (op.addrMode == AddrMode.Accumulator) {
          regA = tmp;
          fZero = regA.getZeroBit();
        } else {
          write(absAddr, tmp);
        }

        fCarry = fetched.getBit(7);
        fNegative = tmp.getNegativeBit();
        return 0;

      case Instr.ROR:
        int tmp = (fetched >> 1).setBit(7, fCarry);

        if (op.addrMode == AddrMode.Accumulator) {
          regA = tmp;
          fZero = regA.getZeroBit();
        } else {
          write(absAddr, tmp);
        }

        fCarry = fetched.getBit(0);
        fNegative = fetched.getNegativeBit();
        return 0;

      case Instr.RTI:
        regPS = _popStack();
        regPC = _popStack16Bit();

        fInterruptDisable = 0;
        return 0;

      case Instr.RTS:
        regPC = _popStack16Bit() + 1;
        return 0;

      case Instr.SBC:
        int tmp = regA - fetched - (1 - fCarry);

        int overflow = (tmp ^ regA) & (tmp ^ fetched) & 0x80;

        fCarry = tmp > 0xff ? 0 : 1;
        fZero = tmp.getZeroBit();
        fOverflow = overflow >> 7;
        fNegative = tmp.getNegativeBit();

        regA = tmp & 0xff;
        return 0;

      case Instr.SEC:
        fCarry = 1;
        return 0;

      case Instr.SED:
        fDecimalMode = 1;
        return 0;

      case Instr.SEI:
        fInterruptDisable = 1;
        return 0;

      case Instr.STA:
        write(absAddr, regA);
        return 0;

      case Instr.STX:
        write(absAddr, regX);
        return 0;

      case Instr.STY:
        write(absAddr, regY);
        return 0;

      case Instr.TAX:
        regX = regA;

        fZero = regX.getZeroBit();
        fNegative = regX.getNegativeBit();
        return 0;

      case Instr.TAY:
        regY = regA;

        fZero = regY.getZeroBit();
        fNegative = regY.getNegativeBit();
        return 0;

      case Instr.TSX:
        regX = regSP;

        fZero = regX.getZeroBit();
        fNegative = regX.getNegativeBit();
        return 0;

      case Instr.TXA:
        regA = regX;

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        return 0;

      case Instr.TXS:
        regSP = regX;
        return 0;

      case Instr.TYA:
        regA = regY;

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        return 0;

      case Instr.ALR:
        execute(Instr.AND);
        execute(Instr.LSR);
        return 0;

      case Instr.ANC:
        regA &= fetched;

        fCarry = regA.getBit(7);
        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        return 0;

      case Instr.ARR:
        execute(Instr.AND);
        execute(Instr.ROR);
        return 0;

      case Instr.AXS:
        regX &= regA;

        fCarry = 0;
        fZero = regX.getZeroBit();
        fNegative = regX.getNegativeBit();
        return 0;

      case Instr.LAX:
        regX = regA = fetched;

        fZero = regA.getZeroBit();
        fNegative = regA.getNegativeBit();
        return 0;

      case Instr.SAX:
        regX &= regA;
        write(absAddr, regX);
        return 0;

      case Instr.DCP:
        execute(Instr.DEC);
        execute(Instr.CMP);
        return 0;

      case Instr.ISC:
        execute(Instr.INC);
        execute(Instr.SBC);
        return 0;

      case Instr.RLA:
        execute(Instr.ROL);
        execute(Instr.AND);
        return 0;

      case Instr.RRA:
        execute(Instr.ROR);
        execute(Instr.ADC);
        return 0;

      case Instr.SLO:
        execute(Instr.ASL);
        execute(Instr.ORA);
        return 0;

      case Instr.SRE:
        execute(Instr.LSR);
        execute(Instr.EOR);
        return 0;
    }

    return 0;
  }

  clock() {
    if (cycles == 0) {
      op = CPU_OPS[read(regPC)];
      regPC++;

      cycles = op.cycles;

      int extraCycles1 = addressing(op.addrMode);
      int extraCycles2 = execute(op.instr);

      cycles += extraCycles1 & extraCycles2;
    }

    cycles--;
  }

  int read(int address) {
    address &= 0xffff;

    // [0x0000, 0x0800] is RAM, [0x0800, 0x02000] is mirrors
    if (address < 0x2000) return bus.cpuWorkRAM.read(address % 0x800);

    // access PPU Registers
    if (address == 0x2000) return bus.ppu.regCTRL;
    if (address == 0x2001) return bus.ppu.getPPUMASK();
    if (address == 0x2002) return bus.ppu.getPPUSTATUS();
    if (address == 0x2003) return bus.ppu.getOAMADDR();
    if (address == 0x2004) return bus.ppu.getOAMDATA();
    if (address == 0x2005) return 0;
    if (address == 0x2006) return 0;
    if (address == 0x2007) return bus.ppu.getPPUDATA();

    // access PPU Registers mirrors
    if (address < 0x4000) return read(0x2000 + address % 0x0008);

    // access APU and joypad registers and ppu 0x4014;
    if (address < 4020) {
      if (address == 0x4014) return 0;
    }

    // Expansion ROM
    if (address < 0x6000) {
      return 0;
    }

    // SRAM
    if (address < 0x8000) {
      if (bus.cardtridge.sRAM != null) {
        return bus.cardtridge.sRAM.read(address - 0x6000);
      }
      return 0;
    }

    // PRG ROM
    if (address < 0x10000) {
      return bus.cardtridge.readPRG(address - 0x8000);
    }

    throw ("cpu reading: address ${address.toRadixString(16)} is over memory map size.");
  }

  void write(int address, int value) {
    address &= 0xffff;

    // write work RAM & mirrors
    if (address < 0x2000) {
      return bus.cpuWorkRAM.write(address % 0x800, value);
    }

    // access PPU Registers
    if (address == 0x2000) return bus.ppu.setPPUCTRL(value);
    if (address == 0x2001) return bus.ppu.setPPUMASK(value);
    if (address == 0x2002) throw ("CPU can not write PPUSTATUS register");
    if (address == 0x2003) return bus.ppu.setOAMADDR(value);
    if (address == 0x2004) return bus.ppu.setOAMDATA(value);
    if (address == 0x2005) return bus.ppu.setPPUSCROLL(value);
    if (address == 0x2006) return bus.ppu.setPPUADDR(value);
    if (address == 0x2007) return bus.ppu.setPPUDATA(value);

    // access PPU Registers mirrors
    if (address < 0x4000) {
      return write(0x2000 + address % 0x0008, value);
    }

    // APU and joypad registers and ppu 0x4014;
    if (address < 4020) {
      if (address == 0x4014) {
        bus.ppu.setOAMDMA(value);
        // dmaCycles = 514;
        return;
      }
    }

    // Expansion ROM
    if (address < 0x6000) {
      return;
    }

    // SRAM
    if (address < 0x8000) {
      if (bus.cardtridge.sRAM != null) {
        bus.cardtridge.sRAM.write(address - 0x6000, value);
      }
      return;
    }

    // PRG ROM
    if (address < 0x10000) {
      return;
    }

    throw ("cpu writing: address ${address.toRadixString(16)} is over memory map size.");
  }

  int read16Bit(int address) {
    return read(address + 1) << 8 | read(address);
  }
}
