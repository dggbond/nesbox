library flutter_nes;

import 'dart:typed_data';

import 'package:flutter_nes/memory.dart';
import 'package:flutter_nes/cpu_enum.dart';
import 'package:flutter_nes/cpu_utils.dart' show Int8Util;

// emualtor for 6502 CPU
class NesCpu {
  NesCpuMemory _memory = NesCpuMemory();

  // this is registers
  // see https://en.wikipedia.org/wiki/MOS_Technology_6502#Registers
  int _regPC = 0; // Program Counter, the only 16-bit register, others are 8-bit
  int _regSP = 0x100; // Stack Pointer register
  int _regPS = 0; // Processor Status register
  int _regACC = 0; // Accumulator register
  int _regX = 0; // Index register, used for indexed addressing mode
  int _regY = 0; // Index register

  // execute one instruction
  emulate(Op op, Int8List nextBytes) {
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
        break;

      case AddrMode.AbsoluteY:
        addr = Int8Util.join(nextBytes[1], nextBytes[0]) + _regY;
        value = _memory.read(addr);
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
        break;

      case AddrMode.IndirectIndexed:
        addr = Int8Util.join(_memory.read(nextBytes[0] + 1), _memory.read(nextBytes[0])) + _regY;
        value = _memory.read(addr);
        break;

      default:
        throw ('cpu emulate: ${op.addrMode} is an unknown addressing mode.');
    }

    // this means is addressing 16bit addr, so it takes one more cycle.
    if (addr & 0xffff > 0xff) {
      extraCycles++;
    }

    switch (op.ins) {
      case InsEnum.ADC:
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

      case InsEnum.AND:
        _regACC = _regACC & value & 0xff;

        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(_regACC));
        break;

      case InsEnum.ASL:
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

      case InsEnum.BCC:
        if (_getCarryFlag() == 0) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case InsEnum.BCS:
        if (_getCarryFlag() == 1) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case InsEnum.BEQ:
        if (_getZeroFlag() == 1) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case InsEnum.BIT:
        int result = value & _regACC;

        _setZeroFlag(Int8Util.isZero(result));
        _setOverflowFlag(Int8Util.getBitValue(value, 6));
        _setNegativeFlag(Int8Util.isNegative(value));
        break;

      case InsEnum.BMI:
        if (_getNegativeFlag() == 1) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case InsEnum.BNE:
        if (_getZeroFlag() == 0) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case InsEnum.BPL:
        if (_getNegativeFlag() == 0) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case InsEnum.BRK:
        _pushStack(_regPC);
        _pushStack(_regPS);

        _regPC = Int8Util.join(_memory.read(0xffff), _memory.read(0xfffe));
        _setBreakCommandFlag(1);
        break;

      case InsEnum.BVC:
        if (_getOverflowFlag() == 0) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case InsEnum.BVS:
        if (_getOverflowFlag() == 1) {
          extraBytes = value;
          extraCycles++;
        }
        break;

      case InsEnum.CLC:
        _setCarryFlag(0);
        break;

      case InsEnum.CLD:
        _setDecimalModeFlag(0);
        break;

      case InsEnum.CLI:
        _setInterruptDisableFlag(0);
        break;

      case InsEnum.CLV:
        _setOverflowFlag(0);
        break;

      case InsEnum.CMP:
        int result = _regACC - value;

        _setCarryFlag(result > 0 ? 1 : 0);
        _setZeroFlag(result == 0 ? 1 : 0);
        _setNegativeFlag(Int8Util.isNegative(result));
        break;

      case InsEnum.CPX:
        int result = _regX - value;

        _setCarryFlag(result > 0 ? 1 : 0);
        _setZeroFlag(result == 0 ? 1 : 0);
        _setNegativeFlag(Int8Util.isNegative(result));
        break;

      case InsEnum.CPY:
        int result = _regY - value;

        _setCarryFlag(result > 0 ? 1 : 0);
        _setZeroFlag(result == 0 ? 1 : 0);
        _setNegativeFlag(Int8Util.isNegative(result));
        break;

      case InsEnum.DEC:
        int result = value - 1;

        _setZeroFlag(Int8Util.isZero(result));
        _setNegativeFlag(Int8Util.isNegative(result));
        _memory.write(addr, result & 0xff);
        break;

      case InsEnum.DEX:
        _regX -= 1;

        _setZeroFlag(Int8Util.isZero(_regX));
        _setNegativeFlag(Int8Util.isNegative(_regX));
        break;

      case InsEnum.DEY:
        _regY -= 1;

        _setZeroFlag(Int8Util.isZero(_regY));
        _setNegativeFlag(Int8Util.isNegative(_regY));
        break;

      case InsEnum.EOR:
        _regACC = _regACC ^ value & 0xff;

        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(_regACC));
        break;

      case InsEnum.INC:
        value = (value + 1) & 0xff;

        _setZeroFlag(Int8Util.isZero(value));
        _setNegativeFlag(Int8Util.isNegative(value));
        _memory.write(addr, value);
        break;

      case InsEnum.INX:
        _regX += 1;

        _setZeroFlag(Int8Util.isZero(_regX));
        _setNegativeFlag(Int8Util.isNegative(_regX));
        break;

      case InsEnum.INY:
        _regY += 1;

        _setZeroFlag(Int8Util.isZero(_regY));
        _setNegativeFlag(Int8Util.isNegative(_regY));
        break;

      case InsEnum.JMP:
        _regPC = value & 0xff;
        break;

      case InsEnum.JSR:
        _pushStack(_regPC - 1);
        _regPC = addr;
        break;

      case InsEnum.LDA:
        _regACC = value & 0xff;

        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(_regACC));
        break;

      case InsEnum.LDX:
        _regX = value & 0xff;

        _setZeroFlag(Int8Util.isZero(_regX));
        _setNegativeFlag(Int8Util.isNegative(_regX));
        break;

      case InsEnum.LDY:
        _regY = value & 0xff;

        _setZeroFlag(Int8Util.isZero(_regY));
        _setNegativeFlag(Int8Util.isNegative(_regY));
        break;

      case InsEnum.LSR:
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

      case InsEnum.NOP:
        // no operation
        break;

      case InsEnum.ORA:
        _regACC = _regACC | value & 0xff;

        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(_regACC));
        break;

      case InsEnum.PHA:
        _pushStack(_regACC);
        break;

      case InsEnum.PHP:
        _pushStack(_regPS);
        break;

      case InsEnum.PLA:
        _regACC = _popStack();
        break;

      case InsEnum.PLP:
        _regPS = _popStack();
        break;

      case InsEnum.ROL:
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

      case InsEnum.ROR:
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

      case InsEnum.RTI:
        _regPS = _popStack();
        break;

      case InsEnum.RTS:
        _regPC = _popStack() + 1;
        break;

      case InsEnum.SBC:
        int result = _regACC - value - (1 - _getCarryFlag());

        _setCarryFlag(Int8Util.isOverflow(result) == 1 ? 0 : 1);
        _setZeroFlag(Int8Util.isZero(_regACC));
        _setOverflowFlag(Int8Util.isOverflow(result));
        _setNegativeFlag(Int8Util.isNegative(result));
        break;

      case InsEnum.SEC:
        _setCarryFlag(1);
        break;

      case InsEnum.SED:
        _setDecimalModeFlag(1);
        break;

      case InsEnum.SEI:
        _setInterruptDisableFlag(1);
        break;

      case InsEnum.STA:
        _memory.write(addr, _regACC);
        break;

      case InsEnum.STX:
        _memory.write(addr, _regX);
        break;

      case InsEnum.STY:
        _memory.write(addr, _regY);
        break;

      case InsEnum.TAX:
        _regX = _regACC;

        _setZeroFlag(Int8Util.isZero(_regX));
        _setNegativeFlag(Int8Util.isNegative(_regX));
        break;

      case InsEnum.TAY:
        _regY = _regACC;

        _setZeroFlag(Int8Util.isZero(_regY));
        _setNegativeFlag(Int8Util.isNegative(_regY));
        break;

      case InsEnum.TSX:
        _regX = _regSP;

        _setZeroFlag(Int8Util.isZero(_regX));
        _setNegativeFlag(Int8Util.isNegative(_regX));
        break;

      case InsEnum.TXA:
        _regACC = _regX;

        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(_regACC));
        break;

      case InsEnum.TXS:
        _regSP = _regX;
        break;

      case InsEnum.TYA:
        _regACC = _regY;

        _setZeroFlag(Int8Util.isZero(_regACC));
        _setNegativeFlag(Int8Util.isNegative(_regACC));
        break;

      default:
        throw ('cpu emulate: ${op.ins} is an unknown instruction.');
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

  _pushStack(int value) {
    _memory.write(_regSP, value);
    _regSP++;

    _checkStackPoint();
  }

  int _popStack() {
    int value = _memory.read(_regSP);
    _regSP--;

    _checkStackPoint();

    return value;
  }

  _checkStackPoint() {
    int spMod = _regSP % NesCpuMemory.RAM_CHUNK_SIZE;

    // if over current stack range
    if (spMod < 0xff || spMod >= 0x200) {
      _regSP = (_regSP / 0x200).floor() * NesCpuMemory.RAM_CHUNK_SIZE + 0x100;
    }
  }
}
