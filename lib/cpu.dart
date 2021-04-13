import "package:flutter_nes/cpu_enum.dart";
import 'package:flutter_nes/mapper.dart';
export "package:flutter_nes/cpu_enum.dart";

import "package:flutter_nes/memory.dart";
import 'package:flutter_nes/rom.dart';
import "package:flutter_nes/util.dart";
import 'package:flutter_nes/bus.dart';

// emualtor for 6502 CPU
class NesCpu {
  NesCpu([this.bus]);

  NesCpuMemory _memory = NesCpuMemory();
  NesBus bus;
  NesMapper _mapper;

  static const double FREQUENCY = 1.789773; // frequency per microsecond

  // this is registers
  // see https://en.wikipedia.org/wiki/MOS_Technology_6502#Registers
  int _regPC; // Program Counter, the only 16-bit register, others are 8-bit
  Int8 _regSP; // Stack Pointer register
  Int8 _regPS; // Processor Status register
  Int8 _regA; // Accumulator register
  Int8 _regX; // Index register, used for indexed addressing mode
  Int8 _regY; // Index register

  // execute one instruction
  emulate(Op op, List<int> nextBytes) {
    print("running: ${enumToString(op.instr)} ${nextBytes.toHex().padRight(11, " ")}");

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
        addr = to16Bit(nextBytes);
        M = Int8(_memory.read(addr));
        break;

      case AddrMode.AbsoluteX:
        addr = to16Bit(nextBytes) + _regX.value;
        M = Int8(_memory.read(addr));

        if (isPageCrossed(addr, addr - _regX.value)) {
          extraCycles++;
        }

        break;

      case AddrMode.AbsoluteY:
        addr = to16Bit(nextBytes) + _regY.value;
        M = Int8(_memory.read(addr));

        if (isPageCrossed(addr, addr - _regY.value)) {
          extraCycles++;
        }

        break;

      case AddrMode.Indirect:
        addr = _memory.read16Bit(to16Bit(nextBytes));
        M = Int8(_memory.read(addr));
        break;

      // this addressing mode not need to access memory
      case AddrMode.Implied:
        break;

      // this addressing mode is directly access the accumulator (register)
      case AddrMode.Accumulator:
        M = Int8(_regA.value);
        break;

      case AddrMode.Immediate:
        M = Int8(nextBytes[0]);
        break;

      case AddrMode.Relative:
        M = Int8(nextBytes[0]);
        break;

      case AddrMode.IndexedIndirect:
        addr = _memory.read16Bit(nextBytes[0] + _regX.value);
        M = Int8(_memory.read(addr));

        if (isPageCrossed(addr, addr - _regX.value)) {
          extraCycles++;
        }
        break;

      case AddrMode.IndirectIndexed:
        addr = _memory.read16Bit(nextBytes[0]) + _regY.value;
        M = Int8(_memory.read(addr));
        break;
    }

    switch (op.instr) {
      case Instr.ADC:
        _regA += M + Int8(_getCarryFlag());

        _setCarryFlag(_regA.isOverflow());
        _setOverflowFlag(_regA.isOverflow());
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.AND:
        _regA &= M;

        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.ASL:
        M <<= 1;

        if (op.addrMode == AddrMode.Accumulator) {
          _regA = M;
        } else {
          _memory.write(addr, M.value);
        }

        _setCarryFlag(M.getBit(7));
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(M.isNegative());
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
        Int8 test = M & _regA;

        _setZeroFlag(test.isZero());
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

        _pushStack16Bit(_regPC);
        _pushStack(_regPS.value);

        _regPC = to16Bit([_memory.read(0xfffe), _memory.read(0xffff)]);
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
        _setCarryFlag(_regA >= M ? 1 : 0);
        _setZeroFlag((_regA - M).isZero());
        _setNegativeFlag((_regA - M).isNegative());
        break;

      case Instr.CPX:
        _setCarryFlag(_regX >= M ? 1 : 0);
        _setZeroFlag((_regX - M).isZero());
        _setNegativeFlag((_regX - M).isNegative());
        break;

      case Instr.CPY:
        _setCarryFlag(_regY >= M ? 1 : 0);
        _setZeroFlag((_regY - M).isZero());
        _setNegativeFlag((_regY - M).isNegative());
        break;

      case Instr.DEC:
        M -= Int8(1);
        _memory.write(addr, M.value);

        _setZeroFlag(M.isZero());
        _setNegativeFlag(M.isNegative());
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
        _regA ^= M;

        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.INC:
        M += Int8(1);
        _memory.write(addr, M.value);

        _setZeroFlag(M.isZero());
        _setNegativeFlag(M.isNegative());
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
        _pushStack16Bit(_regPC - 1);
        _regPC = addr;
        break;

      case Instr.LDA:
        _regA = M;

        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
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
        M >>= 1;

        if (op.addrMode == AddrMode.Accumulator) {
          _regA = M;
        } else {
          _memory.write(addr, M.value);
        }

        _setCarryFlag(M.getBit(0));
        _setZeroFlag(M.isZero());
        _setNegativeFlag(M.isNegative());
        break;

      // NOPs
      case Instr.NOP:
      case Instr.SKB:
      case Instr.IGN:
        break;

      case Instr.ORA:
        _regA |= M;

        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.PHA:
        _pushStack(_regA.value);
        break;

      case Instr.PHP:
        _pushStack(_regPS.value);
        break;

      case Instr.PLA:
        _regA = Int8(_popStack());
        break;

      case Instr.PLP:
        _regPS = Int8(_popStack());
        break;

      case Instr.ROL:
        M = (M << 1).setBit(0, _getCarryFlag());

        if (op.addrMode == AddrMode.Accumulator) {
          _regA = M;
        } else {
          _memory.write(addr, M.value);
        }

        _setCarryFlag(M.getBit(7));
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(M.isNegative());
        break;

      case Instr.ROR:
        M = (M >> 1).setBit(7, _getCarryFlag());

        if (op.addrMode == AddrMode.Accumulator) {
          _regA = M;
        } else {
          _memory.write(addr, M.value);
        }

        _setCarryFlag(M.getBit(7));
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(M.isNegative());
        break;

      case Instr.RTI:
        _regPS = Int8(_popStack());
        _regPC = _popStack16Bit();

        _setInterruptDisableFlag(0);
        break;

      case Instr.RTS:
        _regPC = _popStack16Bit() + 1;
        break;

      case Instr.SBC:
        _regA -= M + Int8(1 - _getCarryFlag());

        _setCarryFlag(_regA.isOverflow() == 1 ? 0 : 1);
        _setZeroFlag(_regA.isZero());
        _setOverflowFlag(_regA.isOverflow());
        _setNegativeFlag(_regA.isNegative());
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
        _memory.write(addr, _regA.value);
        break;

      case Instr.STX:
        _memory.write(addr, _regX.value);
        break;

      case Instr.STY:
        _memory.write(addr, _regY.value);
        break;

      case Instr.TAX:
        _regX = _regA;

        _setZeroFlag(_regX.isZero());
        _setNegativeFlag(_regX.isNegative());
        break;

      case Instr.TAY:
        _regY = _regA;

        _setZeroFlag(_regY.isZero());
        _setNegativeFlag(_regY.isNegative());
        break;

      case Instr.TSX:
        _regX = _regSP;

        _setZeroFlag(_regX.isZero());
        _setNegativeFlag(_regX.isNegative());
        break;

      case Instr.TXA:
        _regA = _regX;

        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.TXS:
        _regSP = _regX;
        break;

      case Instr.TYA:
        _regA = _regY;

        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.ALR:
        _regA = (_regA & M) >> 1;

        _setCarryFlag(M.getBit(0));
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.ANC:
        _regA &= M;

        _setCarryFlag(_regA.getBit(7));
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.ARR:
        _regA = ((_regA & M) >> 1).setBit(7, _getCarryFlag());

        _setOverflowFlag(_regA.getBit(6) ^ _regA.getBit(5));
        _setCarryFlag(_regA.getBit(6));
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.AXS:
        _regX &= _regA;

        _setCarryFlag(_regX.isOverflow());
        _setZeroFlag(_regX.isZero());
        _setNegativeFlag(_regX.isNegative());
        break;

      case Instr.LAX:
        _regX = _regA = M;

        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.SAX:
        _regX &= _regA;
        _memory.write(addr, _regX.value);
        break;

      case Instr.DCP:
        // DEC
        M -= Int8(1);
        _memory.write(addr, M.value);

        // CMP
        _setCarryFlag(_regA >= M ? 1 : 0);
        _setZeroFlag((_regA - M).isZero());
        _setNegativeFlag((_regA - M).isNegative());
        break;

      case Instr.ISC:
        // INC
        M += Int8(1);
        _memory.write(addr, M.value);

        // SBC
        _regA -= M + Int8(1 - _getCarryFlag());

        _setCarryFlag(_regA.isOverflow() == 1 ? 0 : 1);
        _setZeroFlag(_regA.isZero());
        _setOverflowFlag(_regA.isOverflow());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.RLA:
        // ROL
        M = (M << 1).setBit(0, _getCarryFlag());
        _memory.write(addr, M.value);

        // AND
        _regA &= M;

        _setCarryFlag(M.getBit(7));
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.RRA:
        // ROR
        M = (M >> 1).setBit(7, _getCarryFlag());
        _memory.write(addr, M.value);

        // ADC
        _regA += M + Int8(_getCarryFlag());

        _setCarryFlag(_regA.isOverflow());
        _setOverflowFlag(_regA.isOverflow());
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.SLO:
        // ASL
        M <<= 1;
        _memory.write(addr, M.value);

        // ORA
        _regA |= M;

        _setCarryFlag(M.getBit(7));
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.SRE:
        // LSR
        M >>= 1;
        _memory.write(addr, M.value);

        // EOR
        _regA ^= M;

        _setCarryFlag(M.getBit(0));
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      default:
        throw ("cpu emulate: ${op.instr} is an unknown instruction.");
    }

    _regPC += op.bytes + extraBytes;
    return op.cycles + extraCycles;
  }

  powerOn() {
    reset();

    if (bus == null) return;

    // @TODO, use memory mapper to set program.
    if (bus.rom.prgNum == 2) {
      int prgStart = NesRom.HEADER_SIZE + bus.rom.trainerSize;
      _memory.writeBytes(NesCpuMemory.PRG_ROM_RANGE, bus.readRomBytes([prgStart, prgStart + NesRom.PRG_ROM_BANK_SIZE * 2]));
    }

    _execute();
  }

  void reset() {
    _regPC = NesCpuMemory.LOWER_PRG_ROM_RANGE[0];
    _regSP = Int8(0x1ff);
    _regPS = Int8();
    _regA = Int8();
    _regX = Int8();
    _regY = Int8();
  }

  _execute() async {
    int opcode = _memory.read(_regPC);

    if (opcode == null) {
      print("can't find instruction from opcode: $opcode");
      return;
    }

    Op op = findOp(opcode);
    if (op == null) {
      throw ("${opcode.toHex()} is unknown instruction at rom address ${_regPC.toHex()}");
    }

    int cycles = emulate(op, _memory.readBytes(_regPC + 1, op.bytes - 1));

    await Future.delayed(Duration(microseconds: (FREQUENCY * cycles).round()), _execute);
  }

  // expose the read/write methods on memory
  int read(int addr) => _memory.read(addr);
  void write(int addr, int value) => _memory.write(addr, value);

  int getPC() => _regPC;
  int getSP() => _regSP.value;
  int getPS() => _regPS.value;
  int getACC() => _regA.value;
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
    if (_regSP.value < 0x100) {
      throw ("push stack failed. stack pointer ${_regSP.value.toHex()} is overflow stack area.");
    }

    _memory.write(_regSP.value, value);
    _regSP -= Int8(1);
  }

  int _popStack() {
    if (_regSP.value >= 0x1ff) {
      throw ("pop stack failed. stack pointer ${_regSP.value.toHex()} is at the start of stack area.");
    }

    int value = _memory.read(_regSP.value);
    _regSP += Int8(1);

    return value;
  }

  void _pushStack16Bit(int value) {
    _pushStack(value >> 2 & 0xff);
    _pushStack(value & 0xff);
  }

  int _popStack16Bit() {
    return _popStack() | (_popStack() << 2);
  }
}
