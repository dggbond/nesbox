library cpu;

import "dart:typed_data";

import "cpu_enum.dart";
export "cpu_enum.dart";

import "package:flutter_nes/memory.dart";
import "package:flutter_nes/util.dart";

// emualtor for 6502 CPU
class NesCPU {
  NesCPU();

  NesCpuMemory _memory = NesCpuMemory();

  // this is registers
  // see https://en.wikipedia.org/wiki/MOS_Technology_6502#Registers
  int _regPC = 0; // Program Counter, the only 16-bit register, others are 8-bit
  int _regSP = 0xff; // Stack Pointer register
  int _regPS = 0; // Processor Status register
  int _regACC = 0; // Accumulator register
  int _regX = 0; // Index register, used for indexed addressing mode
  int _regY = 0; // Index register

  // execute one instruction
  emulate(Op op, Uint8List nextBytes) {
    int addr = 0; // memory address will used in operator instruction.
    int value = 0; // the value in memory address of addr
    int extraCycles = 0;
    int extraBytes = 0;

    switch (op.addrMode) {
      case AddrMode.ZeroPage:
        addr = nextBytes[0];
        value = _memory.read(addr);
        break;

      case AddrMode.ZeroPageX:
        addr = nextBytes[0] + _regX;
        value = _memory.read(addr);
        break;

      case AddrMode.ZeroPageY:
        addr = nextBytes[0] + _regY;
        value = _memory.read(addr);
        break;

      case AddrMode.Absolute:
        addr = Int8Util.join(nextBytes[1], nextBytes[0]);
        value = _memory.read(addr);
        break;

      case AddrMode.AbsoluteX:
        addr = Int8Util.join(nextBytes[1], nextBytes[0]) + _regX;
        value = _memory.read(addr);

        if (isPageCrossed(addr, addr - _regX)) {
          extraCycles++;
        }

        break;

      case AddrMode.AbsoluteY:
        addr = Int8Util.join(nextBytes[1], nextBytes[0]) + _regY;
        value = _memory.read(addr);

        if (isPageCrossed(addr, addr - _regY)) {
          extraCycles++;
        }

        break;

      case AddrMode.Indirect:
        int absoluteAddr = Int8Util.join(nextBytes[1], nextBytes[0]);
        addr = _memory.read(absoluteAddr + 1) << 2 + _memory.read(absoluteAddr);
        value = _memory.read(addr);
        break;

      // this addressing mode not need to access memory
      case AddrMode.Implied:
        break;

      // this addressing mode is directly access the accumulator (register)
      case AddrMode.Accumulator:
        value = _regACC;
        break;

      case AddrMode.Immediate:
        value = nextBytes[0];
        break;

      case AddrMode.Relative:
        value = nextBytes[0];
        break;

      case AddrMode.IndirectX:
        addr = Int8Util.join(_memory.read(nextBytes[0] + _regX + 1), _memory.read(nextBytes[0])) + _regX;
        value = _memory.read(addr);
        break;

      case AddrMode.IndirectY:
        addr = Int8Util.join(_memory.read(nextBytes[0] + _regY + 1), _memory.read(nextBytes[0])) + _regY;
        value = _memory.read(addr);

        if (isPageCrossed(addr, addr - _regY)) {
          extraCycles++;
        }

        break;

      case AddrMode.IndirectIndexed:
        addr = Int8Util.join(_memory.read(nextBytes[0] + 1), _memory.read(nextBytes[0])) + _regY;
        value = _memory.read(addr);
        break;
    }

    switch (op.instr) {
      case Instr.ADC:
        int result = value + _regACC + _getCarryFlag();

        // if you don't understand what is overflow, see: http://teaching.idallen.com/dat2343/10f/notes/040_overflow.txt
        if (Int8Util.isSameSign(_regACC, value) && !Int8Util.isSameSign(_regACC, result)) {
          _setOverflowFlag(1);
        } else {
          _setOverflowFlag(0);
        }

        _setCarryFlag(Int8Util.isOverflow(result));
        _setZeroFlag(Int8Util.isZero(result));
        _setNegativeFlag(Int8Util.isNegative(result));

        _regACC = result & 0xff;
        break;

      case Instr.AND:
        _regACC = _regACC & value & 0xff;

        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(_regACC));
        break;

      case Instr.ASL:
        int result = value << 1;

        if (op.addrMode == AddrMode.Accumulator) {
          _regACC = result & 0xff;
        } else {
          _memory.write(addr, result & 0xff);
        }

        _setCarryFlag(Int8Util.getBitValue(value, 7));
        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(result));
        break;

      case Instr.BCC:
        if (_getCarryFlag() == 0) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case Instr.BCS:
        if (_getCarryFlag() == 1) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case Instr.BEQ:
        if (_getZeroFlag() == 1) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case Instr.BIT:
        int result = value & _regACC;

        _setZeroFlag(Int8Util.isZero(result));
        _setOverflowFlag(Int8Util.getBitValue(value, 6));
        _setNegativeFlag(Int8Util.isNegative(value));
        break;

      case Instr.BMI:
        if (_getNegativeFlag() == 1) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case Instr.BNE:
        if (_getZeroFlag() == 0) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case Instr.BPL:
        if (_getNegativeFlag() == 0) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case Instr.BRK:
        // IRQ is ignored when interrupt disable flag is set.
        if (_getInterruptDisableFlag() == 1) break;

        _pushStack(_regPC);
        _pushStack(_regPS);

        _regPC = Int8Util.join(_memory.read(0xffff), _memory.read(0xfffe));
        _setBreakCommandFlag(1);
        break;

      case Instr.BVC:
        if (_getOverflowFlag() == 0) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case Instr.BVS:
        if (_getOverflowFlag() == 1) {
          extraBytes = value;
          extraCycles++;
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
        int result = _regACC - value;

        _setCarryFlag(result > 0 ? 1 : 0);
        _setZeroFlag(result == 0 ? 1 : 0);
        _setNegativeFlag(Int8Util.isNegative(result));
        break;

      case Instr.CPX:
        int result = _regX - value;

        _setCarryFlag(result > 0 ? 1 : 0);
        _setZeroFlag(result == 0 ? 1 : 0);
        _setNegativeFlag(Int8Util.isNegative(result));
        break;

      case Instr.CPY:
        int result = _regY - value;

        _setCarryFlag(result > 0 ? 1 : 0);
        _setZeroFlag(result == 0 ? 1 : 0);
        _setNegativeFlag(Int8Util.isNegative(result));
        break;

      case Instr.DEC:
        int result = value - 1;

        _setZeroFlag(Int8Util.isZero(result));
        _setNegativeFlag(Int8Util.isNegative(result));
        _memory.write(addr, result & 0xff);
        break;

      case Instr.DEX:
        _regX -= 1;

        _setZeroFlag(Int8Util.isZero(_regX));
        _setNegativeFlag(Int8Util.isNegative(_regX));
        break;

      case Instr.DEY:
        _regY -= 1;

        _setZeroFlag(Int8Util.isZero(_regY));
        _setNegativeFlag(Int8Util.isNegative(_regY));
        break;

      case Instr.EOR:
        _regACC = _regACC ^ value & 0xff;

        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(_regACC));
        break;

      case Instr.INC:
        value = (value + 1) & 0xff;

        _setZeroFlag(Int8Util.isZero(value));
        _setNegativeFlag(Int8Util.isNegative(value));
        _memory.write(addr, value);
        break;

      case Instr.INX:
        _regX += 1;

        _setZeroFlag(Int8Util.isZero(_regX));
        _setNegativeFlag(Int8Util.isNegative(_regX));
        break;

      case Instr.INY:
        _regY += 1;

        _setZeroFlag(Int8Util.isZero(_regY));
        _setNegativeFlag(Int8Util.isNegative(_regY));
        break;

      case Instr.JMP:
        _regPC = value & 0xff;
        break;

      case Instr.JSR:
        _pushStack(_regPC - 1);
        _regPC = addr;
        break;

      case Instr.LDA:
        _regACC = value & 0xff;

        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(_regACC));
        break;

      case Instr.LDX:
        _regX = value & 0xff;

        _setZeroFlag(Int8Util.isZero(_regX));
        _setNegativeFlag(Int8Util.isNegative(_regX));
        break;

      case Instr.LDY:
        _regY = value & 0xff;

        _setZeroFlag(Int8Util.isZero(_regY));
        _setNegativeFlag(Int8Util.isNegative(_regY));
        break;

      case Instr.LSR:
        int result = value >> 1;

        if (op.addrMode == AddrMode.Accumulator) {
          _regACC = result & 0xff;
        } else {
          _memory.write(addr, result & 0xff);
        }

        _setCarryFlag(Int8Util.getBitValue(value, 0));
        _setZeroFlag(Int8Util.isZero(result));
        _setNegativeFlag(Int8Util.isNegative(result));
        break;

      case Instr.NOP:
        // no operation
        break;

      case Instr.ORA:
        _regACC = _regACC | value & 0xff;

        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(_regACC));
        break;

      case Instr.PHA:
        _pushStack(_regACC);
        break;

      case Instr.PHP:
        _pushStack(_regPS);
        break;

      case Instr.PLA:
        _regACC = _popStack();
        break;

      case Instr.PLP:
        _regPS = _popStack();
        break;

      case Instr.ROL:
        int result = Int8Util.setBitValue(value << 1, 0, _getCarryFlag());

        if (op.addrMode == AddrMode.Accumulator) {
          _regACC = result & 0xff;
        } else {
          _memory.write(addr, result & 0xff);
        }

        _setCarryFlag(Int8Util.getBitValue(value, 7));
        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(result));
        break;

      case Instr.ROR:
        int result = Int8Util.setBitValue(value >> 1, 7, _getCarryFlag());

        if (op.addrMode == AddrMode.Accumulator) {
          _regACC = result & 0xff;
        } else {
          _memory.write(addr, result & 0xff);
        }

        _setCarryFlag(Int8Util.getBitValue(value, 7));
        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(result));
        break;

      case Instr.RTI:
        _regPC = _popStack();
        _regPS = _popStack();

        _setInterruptDisableFlag(0);
        break;

      case Instr.RTS:
        _regPC = _popStack() + 1;
        break;

      case Instr.SBC:
        int result = _regACC - value - (1 - _getCarryFlag());

        _setCarryFlag(Int8Util.isOverflow(result) == 1 ? 0 : 1);
        _setZeroFlag(Int8Util.isZero(_regACC));
        _setOverflowFlag(Int8Util.isOverflow(result));
        _setNegativeFlag(Int8Util.isNegative(result));
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
        _memory.write(addr, _regACC);
        break;

      case Instr.STX:
        _memory.write(addr, _regX);
        break;

      case Instr.STY:
        _memory.write(addr, _regY);
        break;

      case Instr.TAX:
        _regX = _regACC;

        _setZeroFlag(Int8Util.isZero(_regX));
        _setNegativeFlag(Int8Util.isNegative(_regX));
        break;

      case Instr.TAY:
        _regY = _regACC;

        _setZeroFlag(Int8Util.isZero(_regY));
        _setNegativeFlag(Int8Util.isNegative(_regY));
        break;

      case Instr.TSX:
        _regX = _regSP;

        _setZeroFlag(Int8Util.isZero(_regX));
        _setNegativeFlag(Int8Util.isNegative(_regX));
        break;

      case Instr.TXA:
        _regACC = _regX;

        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(_regACC));
        break;

      case Instr.TXS:
        _regSP = _regX;
        break;

      case Instr.TYA:
        _regACC = _regY;

        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(_regACC));
        break;

      default:
        throw ("cpu emulate: ${op.instr} is an unknown instruction.");
    }

    _regPC += op.bytes + extraBytes;
    return op.cycles + extraCycles;
  }

  int inspectMemory(int addr) => _memory.read(addr);

  int getPC() => _regPC;
  int getSP() => _regSP;
  int getPS() => _regPS;
  int getACC() => _regACC;
  int getX() => _regX;
  int getY() => _regY;

  int _getCarryFlag() => Int8Util.getBitValue(_regPS, 0);
  int _getZeroFlag() => Int8Util.getBitValue(_regPS, 1);
  int _getInterruptDisableFlag() => Int8Util.getBitValue(_regPS, 2);
  int _getDecimalModeFlag() => Int8Util.getBitValue(_regPS, 3);
  int _getBreakCommandFlag() => Int8Util.getBitValue(_regPS, 4);
  int _getOverflowFlag() => Int8Util.getBitValue(_regPS, 6);
  int _getNegativeFlag() => Int8Util.getBitValue(_regPS, 7);

  void _setCarryFlag(int value) {
    _regPS = Int8Util.setBitValue(_regPS, 0, value);
  }

  void _setZeroFlag(int value) {
    _regPS = Int8Util.setBitValue(_regPS, 1, value);
  }

  void _setInterruptDisableFlag(int value) {
    _regPS = Int8Util.setBitValue(_regPS, 2, value);
  }

  void _setDecimalModeFlag(int value) {
    _regPS = Int8Util.setBitValue(_regPS, 3, value);
  }

  void _setBreakCommandFlag(int value) {
    _regPS = Int8Util.setBitValue(_regPS, 4, value);
  }

  void _setOverflowFlag(int value) {
    _regPS = Int8Util.setBitValue(_regPS, 6, value);
  }

  void _setNegativeFlag(int value) {
    _regPS = Int8Util.setBitValue(_regPS, 7, value);
  }

  // stack works top-down, see NESDoc page 12.
  _pushStack(int value) {
    _memory.write(0x100 & _regSP, value);
    _regSP--;
  }

  int _popStack() {
    int value = _memory.read(0x100 & _regSP);
    _regSP++;

    return value;
  }
}
