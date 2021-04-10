library cpu;

import "dart:typed_data";

import "cpu_enum.dart";
export "cpu_enum.dart";

import "package:flutter_nes/memory.dart";
import 'package:flutter_nes/util.dart';

// emualtor for 6502 CPU
class NesCPU {
  NesCPU();

  NesCPUMemory _memory = NesCPUMemory();

  // this is registers
  // see https://en.wikipedia.org/wiki/MOS_Technology_6502#Registers
  int _regPC = 0; // Program Counter, the only 16-bit register, others are 8-bit
  Int8 _regSP = Int8(0xff); // Stack Pointer register
  Int8 _regPS = Int8(); // Processor Status register
  Int8 _regACC = Int8(); // Accumulator register
  Int8 _regX = Int8(); // Index register, used for indexed addressing mode
  Int8 _regY = Int8(); // Index register

  // execute one instruction
  emulate(Op op, Uint8List nextBytes) {
    int addr = 0; // memory address will used in operator instruction.
    Int8 M = Int8(); // the value in memory address of addr
    int extraCycles = 0;
    int extraBytes = 0;

    switch (op.addrMode) {
      case AddrMode.ZeroPage:
        addr = nextBytes[0];
        M = Int8(_memory.read(addr));
        break;

      case AddrMode.ZeroPageX:
        addr = nextBytes[0] + _regX.value;
        M = Int8(_memory.read(addr));
        break;

      case AddrMode.ZeroPageY:
        addr = nextBytes[0] + _regY.value;
        M = Int8(_memory.read(addr));
        break;

      case AddrMode.Absolute:
        addr = get16Bit(nextBytes);
        M = Int8(_memory.read(addr));
        break;

      case AddrMode.AbsoluteX:
        addr = get16Bit(nextBytes) + _regX.value;
        M = Int8(_memory.read(addr));

        if (isPageCrossed(addr, addr - _regX.value)) {
          extraCycles++;
        }

        break;

      case AddrMode.AbsoluteY:
        addr = get16Bit(nextBytes) + _regY.value;
        M = Int8(_memory.read(addr));

        if (isPageCrossed(addr, addr - _regY.value)) {
          extraCycles++;
        }

        break;

      case AddrMode.Indirect:
        int absoluteAddr = get16Bit(nextBytes);
        addr = get16Bit([_memory.read(absoluteAddr), _memory.read(absoluteAddr + 1)]);
        M = Int8(_memory.read(addr));
        break;

      // this addressing mode not need to access memory
      case AddrMode.Implied:
        break;

      // this addressing mode is directly access the accumulator (register)
      case AddrMode.Accumulator:
        M = Int8(_regACC.value);
        break;

      case AddrMode.Immediate:
        M = Int8(nextBytes[0]);
        break;

      case AddrMode.Relative:
        M = Int8(nextBytes[0]);
        break;

      case AddrMode.IndirectX:
        addr = get16Bit([_memory.read(nextBytes[0] + _regX.value), _memory.read(nextBytes[0] + _regX.value + 1)]);
        M = Int8(_memory.read(addr));
        break;

      case AddrMode.IndirectY:
        addr = get16Bit([_memory.read(nextBytes[0] + _regY.value), _memory.read(nextBytes[0] + _regY.value + 1)]);
        M = Int8(_memory.read(addr));

        if (isPageCrossed(addr, addr - _regY.value)) {
          extraCycles++;
        }

        break;

      case AddrMode.IndirectIndexed:
        addr = get16Bit([_memory.read(nextBytes[0]), _memory.read(nextBytes[0] + 1)]) + _regY.value;
        M = Int8(_memory.read(addr));
        break;
    }

    switch (op.instr) {
      case Instr.ADC:
        Int8 result = M + _regACC + Int8(_getCarryFlag());

        // if you don't understand what is overflow, see: http://teaching.idallen.com/dat2343/10f/notes/040_overflow.txt
        if (_regACC.sign == M.sign && _regACC.sign != result.sign) {
          _setOverflowFlag(1);
        } else {
          _setOverflowFlag(0);
        }

        _setCarryFlag(result.isOverflow());
        _setZeroFlag(result.isZero());
        _setNegativeFlag(result.isNegative());

        _regACC = Int8(result.value);
        break;

      case Instr.AND:
        _regACC = _regACC & M;

        _setZeroFlag(_regACC.isZero());
        _setNegativeFlag(_regACC.isNegative());
        break;

      case Instr.ASL:
        Int8 result = M << 1;

        if (op.addrMode == AddrMode.Accumulator) {
          _regACC = result;
        } else {
          _memory.write(addr, result.value);
        }

        _setCarryFlag(M.getBit(7));
        _setZeroFlag(_regACC.isZero());
        _setNegativeFlag(result.isNegative());
        break;

      case Instr.BCC:
        if (_getCarryFlag() == 0) {
          extraBytes = M.value;
          extraCycles++;
        }
        break;

      case Instr.BCS:
        if (_getCarryFlag() == 1) {
          extraBytes = M.value;
          extraCycles++;
        }
        break;

      case Instr.BEQ:
        if (_getZeroFlag() == 1) {
          extraBytes = M.value;
          extraCycles++;
        }
        break;

      case Instr.BIT:
        Int8 result = M & _regACC;

        _setZeroFlag(result.isZero());
        _setOverflowFlag(M.getBit(6));
        _setNegativeFlag(M.isNegative());
        break;

      case Instr.BMI:
        if (_getNegativeFlag() == 1) {
          extraBytes = M.value;
          extraCycles++;
        }
        break;

      case Instr.BNE:
        if (_getZeroFlag() == 0) {
          extraBytes = M.value;
          extraCycles++;
        }
        break;

      case Instr.BPL:
        if (_getNegativeFlag() == 0) {
          extraBytes = M.value;
          extraCycles++;
        }
        break;

      case Instr.BRK:
        // IRQ is ignored when interrupt disable flag is set.
        if (_getInterruptDisableFlag() == 1) break;

        _pushStack(_regPC);
        _pushStack(_regPS.value);

        _regPC = get16Bit([_memory.read(0xfffe), _memory.read(0xffff)]);
        _setBreakCommandFlag(1);
        break;

      case Instr.BVC:
        if (_getOverflowFlag() == 0) {
          extraBytes = M.value;
          extraCycles++;
        }
        break;

      case Instr.BVS:
        if (_getOverflowFlag() == 1) {
          extraBytes = M.value;
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
        Int8 result = _regACC - M;

        _setCarryFlag(_regACC >= M ? 1 : 0);
        _setZeroFlag(result.isZero());
        _setNegativeFlag(result.isNegative());
        break;

      case Instr.CPX:
        Int8 result = _regX - M;

        _setCarryFlag(_regX >= M ? 1 : 0);
        _setZeroFlag(result.isZero());
        _setNegativeFlag(result.isNegative());
        break;

      case Instr.CPY:
        Int8 result = _regY - M;

        _setCarryFlag(_regY >= M ? 1 : 0);
        _setZeroFlag(result.isZero());
        _setNegativeFlag(result.isNegative());
        break;

      case Instr.DEC:
        Int8 result = M - Int8(1);

        _setZeroFlag(result.isZero());
        _setNegativeFlag(result.isNegative());
        _memory.write(addr, result.value);
        break;

      case Instr.DEX:
        _regX -= Int8(1);

        _setZeroFlag(_regX.isZero());
        _setNegativeFlag(_regX.isNegative());
        break;

      case Instr.DEY:
        _regY -= Int8(1);

        _setZeroFlag(_regY.isZero());
        _setNegativeFlag(_regY.isNegative());
        break;

      case Instr.EOR:
        _regACC = _regACC ^ M;

        _setZeroFlag(_regACC.isZero());
        _setNegativeFlag(_regACC.isNegative());
        break;

      case Instr.INC:
        M += Int8(1);

        _setZeroFlag(M.isZero());
        _setNegativeFlag(M.isNegative());
        _memory.write(addr, M.value);
        break;

      case Instr.INX:
        _regX += Int8(1);

        _setZeroFlag(_regX.isZero());
        _setNegativeFlag(_regX.isNegative());
        break;

      case Instr.INY:
        _regY += Int8(1);

        _setZeroFlag(_regY.isZero());
        _setNegativeFlag(_regY.isNegative());
        break;

      case Instr.JMP:
        _regPC = M.value;
        break;

      case Instr.JSR:
        _pushStack(_regPC - 1);
        _regPC = addr;
        break;

      case Instr.LDA:
        _regACC = M;

        _setZeroFlag(_regACC.isZero());
        _setNegativeFlag(_regACC.isNegative());
        break;

      case Instr.LDX:
        _regX = M;

        _setZeroFlag(_regX.isZero());
        _setNegativeFlag(_regX.isNegative());
        break;

      case Instr.LDY:
        _regY = M;

        _setZeroFlag(_regY.isZero());
        _setNegativeFlag(_regY.isNegative());
        break;

      case Instr.LSR:
        Int8 result = M >> 1;

        if (op.addrMode == AddrMode.Accumulator) {
          _regACC = result;
        } else {
          _memory.write(addr, result.value);
        }

        _setCarryFlag(M.getBit(0));
        _setZeroFlag(result.isZero());
        _setNegativeFlag(result.isNegative());
        break;

      case Instr.NOP:
        // no operation
        break;

      case Instr.ORA:
        _regACC = _regACC | M;

        _setZeroFlag(_regACC.isZero());
        _setNegativeFlag(_regACC.isNegative());
        break;

      case Instr.PHA:
        _pushStack(_regACC.value);
        break;

      case Instr.PHP:
        _pushStack(_regPS.value);
        break;

      case Instr.PLA:
        _regACC = Int8(_popStack());
        break;

      case Instr.PLP:
        _regPS = Int8(_popStack());
        break;

      case Instr.ROL:
        Int8 result = (M << 1).setBit(0, _getCarryFlag());

        if (op.addrMode == AddrMode.Accumulator) {
          _regACC = result;
        } else {
          _memory.write(addr, result.value);
        }

        _setCarryFlag(M.getBit(7));
        _setZeroFlag(_regACC.isZero());
        _setNegativeFlag(result.isNegative());
        break;

      case Instr.ROR:
        Int8 result = (M >> 1).setBit(7, _getCarryFlag());

        if (op.addrMode == AddrMode.Accumulator) {
          _regACC = result;
        } else {
          _memory.write(addr, result.value);
        }

        _setCarryFlag(M.getBit(7));
        _setZeroFlag(_regACC.isZero());
        _setNegativeFlag(result.isNegative());
        break;

      case Instr.RTI:
        _regPC = _popStack();
        _regPS = Int8(_popStack());

        _setInterruptDisableFlag(0);
        break;

      case Instr.RTS:
        _regPC = _popStack() + 1;
        break;

      case Instr.SBC:
        Int8 result = _regACC - M - Int8(1 - _getCarryFlag());

        _setCarryFlag(result.isOverflow() == 1 ? 0 : 1);
        _setZeroFlag(_regACC.isZero());
        _setOverflowFlag(result.isOverflow());
        _setNegativeFlag(result.isNegative());
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
        _memory.write(addr, _regACC.value);
        break;

      case Instr.STX:
        _memory.write(addr, _regX.value);
        break;

      case Instr.STY:
        _memory.write(addr, _regY.value);
        break;

      case Instr.TAX:
        _regX = _regACC;

        _setZeroFlag(_regX.isZero());
        _setNegativeFlag(_regX.isNegative());
        break;

      case Instr.TAY:
        _regY = _regACC;

        _setZeroFlag(_regY.isZero());
        _setNegativeFlag(_regY.isNegative());
        break;

      case Instr.TSX:
        _regX = _regSP;

        _setZeroFlag(_regX.isZero());
        _setNegativeFlag(_regX.isNegative());
        break;

      case Instr.TXA:
        _regACC = _regX;

        _setZeroFlag(_regACC.isZero());
        _setNegativeFlag(_regACC.isNegative());
        break;

      case Instr.TXS:
        _regSP = _regX;
        break;

      case Instr.TYA:
        _regACC = _regY;

        _setZeroFlag(_regACC.isZero());
        _setNegativeFlag(_regACC.isNegative());
        break;

      default:
        throw ("cpu emulate: ${op.instr} is an unknown instruction.");
    }

    _regPC += op.bytes + extraBytes;
    return op.cycles + extraCycles;
  }

  int inspectMemory(int addr) => _memory.read(addr);

  int getPC() => _regPC;
  int getSP() => _regSP.value;
  int getPS() => _regPS.value;
  int getACC() => _regACC.value;
  int getX() => _regX.value;
  int getY() => _regY.value;

  int _getCarryFlag() => _regPS.getBit(0);
  int _getZeroFlag() => _regPS.getBit(1);
  int _getInterruptDisableFlag() => _regPS.getBit(2);
  int _getDecimalModeFlag() => _regPS.getBit(3);
  int _getBreakCommandFlag() => _regPS.getBit(4);
  int _getOverflowFlag() => _regPS.getBit(6);
  int _getNegativeFlag() => _regPS.getBit(7);

  void _setCarryFlag(int value) {
    _regPS.setBit(0, value);
  }

  void _setZeroFlag(int value) {
    _regPS.setBit(1, value);
  }

  void _setInterruptDisableFlag(int value) {
    _regPS.setBit(2, value);
  }

  void _setDecimalModeFlag(int value) {
    _regPS.setBit(3, value);
  }

  void _setBreakCommandFlag(int value) {
    _regPS.setBit(4, value);
  }

  void _setOverflowFlag(int value) {
    _regPS.setBit(6, value);
  }

  void _setNegativeFlag(int value) {
    _regPS.setBit(7, value);
  }

  // stack works top-down, see NESDoc page 12.
  _pushStack(int value) {
    _memory.write(0x100 & _regSP.value, value);
    _regSP -= Int8(1);
  }

  int _popStack() {
    int value = _memory.read(0x100 & _regSP.value);
    _regSP -= Int8(1);

    return value;
  }
}
