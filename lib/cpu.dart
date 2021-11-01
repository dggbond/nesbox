import "dart:typed_data";

import "package:flutter_nes/util.dart";
import 'package:flutter_nes/bus.dart';

part "package:flutter_nes/cpu_instructions.dart";

// emualtor for 6502 CPU
class CPU {
  CPU(this.bus);

  BUS bus;

  // this is registers
  // see https://en.wikipedia.org/wiki/MOS_Technology_6502#Registers
  int _regPC; // Program Counter, the only 16-bit register, others are 8-bit
  int _regS; // Stack Pointer register, 8-bit
  int _regP; // Processor Status register, 8-bit
  int _regA; // Accumulator register, 8-bit
  int _regX; // Index register, used for indexed addressing mode, 8-bit
  int _regY; // Index register, 8-bit

  Interrupt interrupt;

  // execute one instruction
  int emulate(Op op) {
    int cycles = op.cycles;

    int addr;
    switch (op.addrMode) {
      case AddrMode.ZeroPage:
        addr = bus.cpuRead(_regPC + 1) % 0xff;
        break;

      case AddrMode.ZeroPageX:
        addr = (bus.cpuRead(_regPC + 1) + _regX) % 0xff;
        break;

      case AddrMode.ZeroPageY:
        addr = (bus.cpuRead(_regPC + 1) + _regY) % 0xff;
        break;

      case AddrMode.Absolute:
        addr = bus.cpuRead16Bit(_regPC + 1);
        break;

      case AddrMode.AbsoluteX:
        addr = bus.cpuRead16Bit(_regPC + 1) + _regX;

        if (isPageCrossed(addr, addr - _regX)) cycles++;
        break;

      case AddrMode.AbsoluteY:
        addr = bus.cpuRead16Bit(_regPC + 1) + _regY;

        if (isPageCrossed(addr, addr - _regY)) cycles++;
        break;

      case AddrMode.Indirect:
        addr = bus.cpuRead16Bit(bus.cpuRead16Bit(_regPC + 1));
        break;

      // these addressing mode not need to access memory
      case AddrMode.Implied:
      case AddrMode.Accumulator:
        break;

      case AddrMode.Immediate:
        addr = _regPC + 1;
        break;

      case AddrMode.Relative:
        int offset = bus.cpuRead(_regPC + 1);
        // offset is a signed integer
        addr = offset >= 0x80 ? offset - 0x100 : offset;
        break;

      case AddrMode.IndexedIndirect:
        addr = bus.cpuRead16Bit(bus.cpuRead((_regPC + 1 + _regX) % 0xff));
        break;

      case AddrMode.IndirectIndexed:
        addr = bus.cpuRead16Bit(bus.cpuRead(_regPC + 1)) + _regY;

        if (isPageCrossed(addr, addr - _regY)) cycles++;
        break;
    }

    // update PC register
    _regPC += op.bytes;

    switch (op.instr) {
      case Instr.ADC:
        int M = bus.cpuRead(addr);
        int result = _regA + M + _getCarryFlag();

        // overflow is basically negative + negative = positive
        // postive + positive = negative
        int overflow = (result ^ _regA) & (result ^ M) & 0x80;

        _setCarryFlag(result > 0xff ? 1 : 0);
        _setOverflowFlag(overflow >> 7);
        _setZeroFlag(result.getZeroBit());
        _setNegativeFlag(result.getNegativeBit());

        _regA = result & 0xff;
        break;

      case Instr.AND:
        _regA &= bus.cpuRead(addr);

        _setZeroFlag(_regA.getZeroBit());
        _setNegativeFlag(_regA.getNegativeBit());
        break;

      case Instr.ASL:
        int M = op.addrMode == AddrMode.Accumulator ? _regA : bus.cpuRead(addr);
        int result = (M << 1) & 0xff;

        if (op.addrMode == AddrMode.Accumulator) {
          _regA = result;
        } else {
          bus.cpuWrite(addr, result);
        }

        _setCarryFlag(M.getBit(7));
        _setZeroFlag(result.getZeroBit());
        _setNegativeFlag(result.getNegativeBit());
        break;

      case Instr.BCC:
        if (_getCarryFlag() == 0) {
          _regPC += addr;
          cycles += isPageCrossed(_regPC, _regPC - addr) ? 2 : 1;
        }

        break;

      case Instr.BCS:
        if (_getCarryFlag() == 1) {
          _regPC += addr;
          cycles += isPageCrossed(_regPC, _regPC - addr) ? 2 : 1;
        }
        break;

      case Instr.BEQ:
        if (_getZeroFlag() == 1) {
          _regPC += addr;
          cycles += isPageCrossed(_regPC, _regPC - addr) ? 2 : 1;
        }
        break;

      case Instr.BIT:
        int M = bus.cpuRead(addr);
        int test = M & _regA;

        _setZeroFlag(test.getZeroBit());
        _setOverflowFlag(M.getBit(6));
        _setNegativeFlag(M.getNegativeBit());
        break;

      case Instr.BMI:
        if (_getNegativeFlag() == 1) {
          _regPC += addr;
          cycles += isPageCrossed(_regPC, _regPC - addr) ? 2 : 1;
        }
        break;

      case Instr.BNE:
        if (_getZeroFlag() == 0) {
          _regPC += addr;
          cycles += isPageCrossed(_regPC, _regPC - addr) ? 2 : 1;
        }
        break;

      case Instr.BPL:
        if (_getNegativeFlag() == 0) {
          _regPC += addr;
          cycles += isPageCrossed(_regPC, _regPC - addr) ? 2 : 1;
        }
        break;

      case Instr.BRK:
        _pushStack16Bit(_regPC + 1);
        _pushStack(_regP);

        _setInterruptDisableFlag(1);
        _setBreakCommandFlag(1);

        _regPC = bus.cpuRead16Bit(0xfffe);
        break;

      case Instr.BVC:
        if (_getOverflowFlag() == 0) {
          _regPC += addr;
          cycles += 1;
        }
        break;

      case Instr.BVS:
        if (_getOverflowFlag() == 1) {
          _regPC += addr;
          cycles += isPageCrossed(_regPC, _regPC - addr) ? 2 : 1;
        }
        break;

      case Instr.CLC:
        _setCarryFlag(0);
        break;

      case Instr.CLD:
        _setDecimalModeFlag(0);
        break;

      case Instr.CLI:
        _setInterruptDisableFlag(0);
        break;

      case Instr.CLV:
        _setOverflowFlag(0);
        break;

      case Instr.CMP:
        int result = _regA - bus.cpuRead(addr);

        _setCarryFlag(result >= 0 ? 1 : 0);
        _setZeroFlag(result.getZeroBit());
        _setNegativeFlag(result.getNegativeBit());
        break;

      case Instr.CPX:
        int result = _regX - bus.cpuRead(addr);

        _setCarryFlag(result >= 0 ? 1 : 0);
        _setZeroFlag(result.getZeroBit());
        _setNegativeFlag(result.getNegativeBit());
        break;

      case Instr.CPY:
        int result = _regY - bus.cpuRead(addr);

        _setCarryFlag(result >= 0 ? 1 : 0);
        _setZeroFlag(result.getZeroBit());
        _setNegativeFlag(result.getNegativeBit());
        break;

      case Instr.DEC:
        int M = bus.cpuRead(addr) - 1;
        bus.cpuWrite(addr, M & 0xff);

        _setZeroFlag(M.getZeroBit());
        _setNegativeFlag(M.getNegativeBit());
        break;

      case Instr.DEX:
        _regX = (_regX - 1) & 0xff;

        _setZeroFlag(_regX.getZeroBit());
        _setNegativeFlag(_regX.getNegativeBit());
        break;

      case Instr.DEY:
        _regY = (_regY - 1) & 0xff;

        _setZeroFlag(_regY.getZeroBit());
        _setNegativeFlag(_regY.getNegativeBit());
        break;

      case Instr.EOR:
        _regA ^= bus.cpuRead(addr);

        _setZeroFlag(_regA.getZeroBit());
        _setNegativeFlag(_regA.getNegativeBit());
        break;

      case Instr.INC:
        int M = bus.cpuRead(addr) + 1;
        bus.cpuWrite(addr, M & 0xff);

        _setZeroFlag(M.getZeroBit());
        _setNegativeFlag(M.getNegativeBit());
        break;

      case Instr.INX:
        _regX = (_regX + 1) & 0xff;

        _setZeroFlag(_regX.getZeroBit());
        _setNegativeFlag(_regX.getNegativeBit());
        break;

      case Instr.INY:
        _regY = (_regY + 1) & 0xff;

        _setZeroFlag(_regY.getZeroBit());
        _setNegativeFlag(_regY.getNegativeBit());
        break;

      case Instr.JMP:
        _regPC = addr;
        break;

      case Instr.JSR:
        _pushStack16Bit(_regPC - 1);
        _regPC = addr;
        break;

      case Instr.LDA:
        _regA = bus.cpuRead(addr);

        _setZeroFlag(_regA.getZeroBit());
        _setNegativeFlag(_regA.getNegativeBit());
        break;

      case Instr.LDX:
        _regX = bus.cpuRead(addr);

        _setZeroFlag(_regX.getZeroBit());
        _setNegativeFlag(_regX.getNegativeBit());
        break;

      case Instr.LDY:
        _regY = bus.cpuRead(addr);

        _setZeroFlag(_regY.getZeroBit());
        _setNegativeFlag(_regY.getNegativeBit());
        break;

      case Instr.LSR:
        int M = op.addrMode == AddrMode.Accumulator ? _regA : bus.cpuRead(addr);
        int result = (M >> 1) & 0xff;

        if (op.addrMode == AddrMode.Accumulator) {
          _regA = result;
        } else {
          bus.cpuWrite(addr, result);
        }

        _setCarryFlag(M.getBit(7));
        _setZeroFlag(result.getZeroBit());
        _setNegativeFlag(result.getNegativeBit());
        break;

      // NOPs
      case Instr.NOP:
      case Instr.SKB:
      case Instr.IGN:
        break;

      case Instr.ORA:
        _regA |= bus.cpuRead(addr);

        _setZeroFlag(_regA.getZeroBit());
        _setNegativeFlag(_regA.getNegativeBit());
        break;

      case Instr.PHA:
        _pushStack(_regA);
        break;

      case Instr.PHP:
        _pushStack(_regP);
        break;

      case Instr.PLA:
        _regA = _popStack();

        _setZeroFlag(_regA.getZeroBit());
        _setNegativeFlag(_regA.getNegativeBit());
        break;

      case Instr.PLP:
        _regP = _popStack();
        break;

      case Instr.ROL:
        int M = op.addrMode == AddrMode.Accumulator ? _regA : bus.cpuRead(addr);
        int result = (M << 1).setBit(0, _getCarryFlag());

        if (op.addrMode == AddrMode.Accumulator) {
          _regA = result;
          _setZeroFlag(_regA.getZeroBit());
        } else {
          bus.cpuWrite(addr, result);
        }

        _setCarryFlag(M.getBit(7));
        _setNegativeFlag(result.getNegativeBit());
        break;

      case Instr.ROR:
        int M = op.addrMode == AddrMode.Accumulator ? _regA : bus.cpuRead(addr);
        int result = (M >> 1).setBit(7, _getCarryFlag());

        if (op.addrMode == AddrMode.Accumulator) {
          _regA = result;
          _setZeroFlag(_regA.getZeroBit());
        } else {
          bus.cpuWrite(addr, result);
        }

        _setCarryFlag(M.getBit(0));
        _setNegativeFlag(M.getNegativeBit());
        break;

      case Instr.RTI:
        _regP = _popStack();
        _regPC = _popStack16Bit();

        _setInterruptDisableFlag(0);
        break;

      case Instr.RTS:
        _regPC = _popStack16Bit() + 1;
        break;

      case Instr.SBC:
        int M = bus.cpuRead(addr);
        int result = _regA - M - (1 - _getCarryFlag());

        int overflow = (result ^ _regA) & (result ^ M) & 0x80;

        _setCarryFlag(result > 0xff ? 0 : 1);
        _setZeroFlag(result.getZeroBit());
        _setOverflowFlag(overflow >> 7);
        _setNegativeFlag(result.getNegativeBit());

        _regA = result & 0xff;
        break;

      case Instr.SEC:
        _setCarryFlag(1);
        break;

      case Instr.SED:
        _setDecimalModeFlag(1);
        break;

      case Instr.SEI:
        _setInterruptDisableFlag(1);
        break;

      case Instr.STA:
        bus.cpuWrite(addr, _regA);
        break;

      case Instr.STX:
        bus.cpuWrite(addr, _regX);
        break;

      case Instr.STY:
        bus.cpuWrite(addr, _regY);
        break;

      case Instr.TAX:
        _regX = _regA;

        _setZeroFlag(_regX.getZeroBit());
        _setNegativeFlag(_regX.getNegativeBit());
        break;

      case Instr.TAY:
        _regY = _regA;

        _setZeroFlag(_regY.getZeroBit());
        _setNegativeFlag(_regY.getNegativeBit());
        break;

      case Instr.TSX:
        _regX = _regS;

        _setZeroFlag(_regX.getZeroBit());
        _setNegativeFlag(_regX.getNegativeBit());
        break;

      case Instr.TXA:
        _regA = _regX;

        _setZeroFlag(_regA.getZeroBit());
        _setNegativeFlag(_regA.getNegativeBit());
        break;

      case Instr.TXS:
        _regS = _regX;
        break;

      case Instr.TYA:
        _regA = _regY;

        _setZeroFlag(_regA.getZeroBit());
        _setNegativeFlag(_regA.getNegativeBit());
        break;

      case Instr.ALR:
        emulate(Op(Instr.AND, AddrMode.Immediate, 0, 0));
        emulate(Op(Instr.LSR, AddrMode.Accumulator, 0, 0));
        break;

      case Instr.ANC:
        _regA &= bus.cpuRead(addr);

        _setCarryFlag(_regA.getBit(7));
        _setZeroFlag(_regA.getZeroBit());
        _setNegativeFlag(_regA.getNegativeBit());
        break;

      case Instr.ARR:
        emulate(Op(Instr.AND, AddrMode.Immediate, 0, 0));
        emulate(Op(Instr.ROR, AddrMode.Accumulator, 0, 0));
        break;

      case Instr.AXS:
        _regX &= _regA;

        _setCarryFlag(0);
        _setZeroFlag(_regX.getZeroBit());
        _setNegativeFlag(_regX.getNegativeBit());
        break;

      case Instr.LAX:
        _regX = _regA = bus.cpuRead(addr);

        _setZeroFlag(_regA.getZeroBit());
        _setNegativeFlag(_regA.getNegativeBit());
        break;

      case Instr.SAX:
        _regX &= _regA;
        bus.cpuWrite(addr, _regX);
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
        debugLog("cpu nmi handled.");
        _pushStack16Bit(_regPC);
        _pushStack(_regP);

        // Set the interrupt disable flag to prevent further interrupts.
        _setInterruptDisableFlag(1);

        _regPC = bus.cpuRead16Bit(0xfffa);
        interrupt = null;

        return 7;
      case Interrupt.IRQ:
        interrupt = null;
        // IRQ is ignored when interrupt disable flag is set.
        if (_getInterruptDisableFlag() == 1) break;

        _pushStack16Bit(_regPC);
        _pushStack(_regP);

        _setInterruptDisableFlag(1);
        _setBreakCommandFlag(0);

        _regPC = bus.cpuRead16Bit(0xfffe);

        return 7;
      case Interrupt.RESET:
        reset();
        return 7;
    }

    int opcode = bus.cpuRead(_regPC);

    if (opcode == null) {
      throw ("can't find instruction at: ${_regPC.toHex()}");
    }

    Op op = NES_CPU_OPS[opcode];
    if (op == null) {
      throw ("${opcode.toHex(2)} is unknown instruction at rom address ${_regPC.toHex()}");
    }

    Uint8List nextBytes = Uint8List(op.bytes - 1);

    for (int n = 0; n < op.bytes - 1; n++) {
      nextBytes[n] = bus.cardtridge.readPRG(_regPC + n + 1 - 0x8000);
    }

    debugLog(
        "${_getStatusOfAllRegisters()} ${opcode.toHex(2)} ${op.name} ${nextBytes.toHex(2)}");

    return emulate(op);
  }

  int _getCarryFlag() => _regP.getBit(0);
  int _getZeroFlag() => _regP.getBit(1);
  int _getInterruptDisableFlag() => _regP.getBit(2);
  // int _getDecimalModeFlag() => _regP.getBit(3); // decimal mode flag is not used
  int _getBreakCommandFlag() => _regP.getBit(4);
  int _getOverflowFlag() => _regP.getBit(6);
  int _getNegativeFlag() => _regP.getBit(7);

  void _setCarryFlag(int value) => _regP = _regP.setBit(0, value);
  void _setZeroFlag(int value) => _regP = _regP.setBit(1, value);
  void _setInterruptDisableFlag(int value) => _regP = _regP.setBit(2, value);
  void _setDecimalModeFlag(int value) => _regP = _regP.setBit(3, value);
  void _setBreakCommandFlag(int value) => _regP = _regP.setBit(4, value);
  void _setOverflowFlag(int value) => _regP = _regP.setBit(6, value);
  void _setNegativeFlag(int value) => _regP = _regP.setBit(7, value);

  // stack works top-down, see NESDoc page 12.
  _pushStack(int value) {
    if (_regS < 0) {
      throw ("push stack failed. stack pointer ${_regS.toHex()} is overflow stack area.");
    }

    bus.cpuWrite(0x100 + _regS, value);
    _regS -= 1;
  }

  int _popStack() {
    if (_regS > 0xff) {
      throw ("pop stack failed. stack pointer ${_regS.toHex()} is at the start of stack area.");
    }

    _regS += 1;
    int value = bus.cpuRead(0x100 + _regS);

    return value;
  }

  void _pushStack16Bit(int value) {
    _pushStack(value >> 8 & 0xff);
    _pushStack(value & 0xff);
  }

  int _popStack16Bit() {
    return _popStack() | (_popStack() << 8);
  }

  void reset() {
    _regPC = bus.cpuRead16Bit(0xfffc);
    _regS = 0xfd;

    _setInterruptDisableFlag(1);

    // TODO APU register reset
  }

  // CPU power-up state see: https://wiki.nesdev.com/w/index.php/CPU_power_up_state
  void powerOn() {
    _regPC = bus.cpuRead16Bit(0xfffc);
    _regP = 0x34;
    _regS = 0xfd;
    _regA = 0x00;
    _regX = 0x00;
    _regY = 0x00;
  }
}

extension DebugExtension on CPU {
  String _getStatusOfAllRegisters() {
    return "C:${_getCarryFlag()}" +
        " Z:${_getZeroFlag()}" +
        " I:${_getInterruptDisableFlag()}" +
        " B:${_getBreakCommandFlag()}" +
        " O:${_getOverflowFlag()}" +
        " N:${_getNegativeFlag()}" +
        " PC:${_regPC.toHex()}" +
        " S:${_regS.toHex(2)}" +
        " A:${_regA.toHex(2)}" +
        " X:${_regX.toHex(2)}" +
        " Y:${_regY.toHex(2)}";
  }
}
