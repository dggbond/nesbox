import "dart:typed_data";

import 'package:flutter_nes/int8.dart';
import "package:flutter_nes/util.dart";
import 'package:flutter_nes/bus.dart';

part "package:flutter_nes/cpu_enum.dart";

// emualtor for 6502 CPU
class CPU {
  static const double MICRO_SEC_PER_CYCLE = 1 / 1.789773; // how many microseconds take per cycle

  CPU(this.bus);

  BUS bus;

  // this is registers
  // see https://en.wikipedia.org/wiki/MOS_Technology_6502#Registers
  int _regPC; // Program Counter, the only 16-bit register, others are 8-bit
  Int8 _regSP; // Stack Pointer register
  Int8 _regPS; // Processor Status register
  Int8 _regA; // Accumulator register
  Int8 _regX; // Index register, used for indexed addressing mode
  Int8 _regY; // Index register

  int costCycles = 0; // extra cycles cost when execute the instruction.

  // execute one instruction
  int emulate(Op op, List<int> nextBytes) {
    int addr = 0; // memory address will used in operator instruction.
    Int8 M = Int8(); // the .value in memory address of addr
    int nextPC = _regPC + op.bytes; // the target program counter then jump to.

    switch (op.addrMode) {
      case AddrMode.ZeroPage:
        addr = nextBytes[0];
        M = Int8(bus.cpuRead(addr));
        break;

      case AddrMode.ZeroPageX:
        addr = nextBytes[0] + _regX.toInt();
        M = Int8(bus.cpuRead(addr));
        break;

      case AddrMode.ZeroPageY:
        addr = nextBytes[0] + _regY.toInt();
        M = Int8(bus.cpuRead(addr));
        break;

      case AddrMode.Absolute:
        addr = to16Bit(nextBytes);
        M = Int8(bus.cpuRead(addr));
        break;

      case AddrMode.AbsoluteX:
        addr = to16Bit(nextBytes) + _regX.toInt();
        M = Int8(bus.cpuRead(addr));

        if (isPageCrossed(addr, addr - _regX.toInt())) {
          costCycles++;
        }

        break;

      case AddrMode.AbsoluteY:
        addr = to16Bit(nextBytes) + _regY.toInt();
        M = Int8(bus.cpuRead(addr));

        if (isPageCrossed(addr, addr - _regY.toInt())) {
          costCycles++;
        }

        break;

      case AddrMode.Indirect:
        addr = bus.cpuRead16Bit(to16Bit(nextBytes));
        M = Int8(bus.cpuRead(addr));
        break;

      // this addressing mode not need to access memory
      case AddrMode.Implied:
        break;

      // this addressing mode is directly access the accumulator (register)
      case AddrMode.Accumulator:
        M = Int8(_regA.toInt());
        break;

      case AddrMode.Immediate:
        M = Int8(nextBytes[0]);
        break;

      case AddrMode.Relative:
        addr = nextBytes[0];
        break;

      case AddrMode.IndexedIndirect:
        addr = bus.cpuRead16Bit(nextBytes[0] + _regX.toInt());
        M = Int8(bus.cpuRead(addr));

        if (isPageCrossed(addr, addr - _regX.toInt())) {
          costCycles++;
        }
        break;

      case AddrMode.IndirectIndexed:
        addr = bus.cpuRead16Bit(nextBytes[0]) + _regY.toInt();
        M = Int8(bus.cpuRead(addr));
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
          bus.cpuWrite(addr, M.toInt());
        }

        _setCarryFlag(M.getBit(7));
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(M.isNegative());
        break;

      case Instr.BCC:
        if (_getCarryFlag() == 0) {
          nextPC += addr;
        }

        costCycles += isPageCrossed(_regPC, nextPC) ? 2 : 1;
        break;

      case Instr.BCS:
        if (_getCarryFlag() == 1) {
          nextPC += addr;
        }
        costCycles += isPageCrossed(_regPC, nextPC) ? 2 : 1;
        break;

      case Instr.BEQ:
        if (_getZeroFlag() == 1) {
          nextPC += addr;
        }
        costCycles += isPageCrossed(_regPC, nextPC) ? 2 : 1;
        break;

      case Instr.BIT:
        Int8 test = M & _regA;

        _setZeroFlag(test.isZero());
        _setOverflowFlag(M.getBit(6));
        _setNegativeFlag(M.isNegative());
        break;

      case Instr.BMI:
        if (_getNegativeFlag() == 1) {
          nextPC += addr;
        }
        costCycles += isPageCrossed(_regPC, nextPC) ? 2 : 1;
        break;

      case Instr.BNE:
        if (_getZeroFlag() == 0) {
          nextPC += addr;
        }
        costCycles += isPageCrossed(_regPC, nextPC) ? 2 : 1;
        break;

      case Instr.BPL:
        if (_getNegativeFlag() == 0) {
          nextPC += addr;
        }
        costCycles += isPageCrossed(_regPC, nextPC) ? 2 : 1;
        break;

      case Instr.BRK:
        _handleIrqInterrupt();
        break;

      case Instr.BVC:
        if (_getOverflowFlag() == 0) {
          nextPC += addr;
        }
        costCycles = isPageCrossed(_regPC, nextPC) ? 2 : 1;
        break;

      case Instr.BVS:
        if (_getOverflowFlag() == 1) {
          nextPC += addr;
        }
        costCycles = isPageCrossed(_regPC, nextPC) ? 2 : 1;
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
        bus.cpuWrite(addr, M.toInt());

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
        bus.cpuWrite(addr, M.toInt());

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
        nextPC = addr;
        break;

      case Instr.JSR:
        _pushStack16Bit(_regPC - 1);
        nextPC = addr;
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
          bus.cpuWrite(addr, M.toInt());
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
        _pushStack(_regA.toInt());
        break;

      case Instr.PHP:
        _pushStack(_regPS.toInt());
        break;

      case Instr.PLA:
        _regA = Int8(_popStack());

        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.PLP:
        _regPS = Int8(_popStack());
        break;

      case Instr.ROL:
        int oldBit7 = M.getBit(7);
        M = (M << 1).setBit(0, _getCarryFlag());

        if (op.addrMode == AddrMode.Accumulator) {
          _regA = M;
        } else {
          bus.cpuWrite(addr, M.toInt());
        }

        _setCarryFlag(oldBit7);
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(M.isNegative());
        break;

      case Instr.ROR:
        int oldBit0 = M.getBit(0);
        M = (M >> 1).setBit(7, _getCarryFlag());

        if (op.addrMode == AddrMode.Accumulator) {
          _regA = M;
        } else {
          bus.cpuWrite(addr, M.toInt());
        }

        _setCarryFlag(oldBit0);
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(M.isNegative());
        break;

      case Instr.RTI:
        _regPS = Int8(_popStack());
        nextPC = _popStack16Bit();

        _setInterruptDisableFlag(0);
        break;

      case Instr.RTS:
        nextPC = _popStack16Bit() + 1;
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
        bus.cpuWrite(addr, _regA.toInt());
        break;

      case Instr.STX:
        bus.cpuWrite(addr, _regX.toInt());
        break;

      case Instr.STY:
        bus.cpuWrite(addr, _regY.toInt());
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
        bus.cpuWrite(addr, _regX.toInt());
        break;

      case Instr.DCP:
        // DEC
        M -= Int8(1);
        bus.cpuWrite(addr, M.toInt());

        // CMP
        _setCarryFlag(_regA >= M ? 1 : 0);
        _setZeroFlag((_regA - M).isZero());
        _setNegativeFlag((_regA - M).isNegative());
        break;

      case Instr.ISC:
        // INC
        M += Int8(1);
        bus.cpuWrite(addr, M.toInt());

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

        if (op.addrMode == AddrMode.Accumulator) {
          _regA = M;
        } else {
          bus.cpuWrite(addr, M.toInt());
        }

        // AND
        _regA &= M;

        _setCarryFlag(M.getBit(7));
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.RRA:
        // ROR
        M = (M >> 1).setBit(7, _getCarryFlag());

        if (op.addrMode == AddrMode.Accumulator) {
          _regA = M;
        } else {
          bus.cpuWrite(addr, M.toInt());
        }

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

        if (op.addrMode == AddrMode.Accumulator) {
          _regA = M;
        } else {
          bus.cpuWrite(addr, M.toInt());
        }

        // ORA
        _regA |= M;

        _setCarryFlag(M.getBit(7));
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      case Instr.SRE:
        // LSR
        M >>= 1;

        if (op.addrMode == AddrMode.Accumulator) {
          _regA = M;
        } else {
          bus.cpuWrite(addr, M.toInt());
        }

        // EOR
        _regA ^= M;

        _setCarryFlag(M.getBit(0));
        _setZeroFlag(_regA.isZero());
        _setNegativeFlag(_regA.isNegative());
        break;

      default:
        throw ("cpu emulate: ${op.instr} is an unknown instruction.");
    }

    _regPC = nextPC & 0xffff;

    int totalCycles = op.cycles + costCycles;

    // clear cost cycles;
    costCycles = 0;

    return totalCycles;
  }

  int tick() {
    int opcode = bus.cpuRead(_regPC);

    if (opcode == null) {
      throw ("can't find instruction from opcode: $opcode");
    }

    Op op = CPU_OPS[opcode];
    if (op == null) {
      throw ("${opcode.toHex()} is unknown instruction at rom address ${_regPC.toHex()}");
    }

    Uint8List nextBytes = Uint8List(op.bytes - 1);

    for (int n = 0; n < op.bytes - 1; n++) {
      nextBytes[n] = bus.cpuRead(_regPC + n + 1);
    }

    debugLog("${_getStatusOfAllRegisters()} ${opcode.toHex(2)} ${op.name} ${nextBytes.toHex()}");

    return emulate(op, nextBytes);
  }

  int _getCarryFlag() => _regPS.getBit(0);
  int _getZeroFlag() => _regPS.getBit(1);
  int _getInterruptDisableFlag() => _regPS.getBit(2);
  int _getDecimalModeFlag() => _regPS.getBit(3);
  int _getBreakCommandFlag() => _regPS.getBit(4);
  int _getOverflowFlag() => _regPS.getBit(6);
  int _getNegativeFlag() => _regPS.getBit(7);

  void _setCarryFlag(int value) => _regPS.setBit(0, value);
  void _setZeroFlag(int value) => _regPS.setBit(1, value);
  void _setInterruptDisableFlag(int value) => _regPS.setBit(2, value);
  void _setDecimalModeFlag(int value) => _regPS.setBit(3, value);
  void _setBreakCommandFlag(int value) => _regPS.setBit(4, value);
  void _setOverflowFlag(int value) => _regPS.setBit(6, value);
  void _setNegativeFlag(int value) => _regPS.setBit(7, value);

  // stack works top-down, see NESDoc page 12.
  _pushStack(int value) {
    if (_regSP.toInt() < 0) {
      throw ("push stack failed. stack pointer ${_regSP.toHex()} is overflow stack area.");
    }

    bus.cpuWrite(0x100 + _regSP.toInt(), value);
    _regSP -= Int8(1);
  }

  int _popStack() {
    if (_regSP.toInt() > 0xff) {
      throw ("pop stack failed. stack pointer ${_regSP.toHex()} is at the start of stack area.");
    }

    _regSP += Int8(1);
    int value = bus.cpuRead(0x100 + _regSP.toInt());

    return value;
  }

  void _pushStack16Bit(int value) {
    _pushStack(value >> 8 & 0xff);
    _pushStack(value & 0xff);
  }

  int _popStack16Bit() {
    return _popStack() | (_popStack() << 8);
  }

  // interrupt handlers
  void _handleIrqInterrupt() {
    // IRQ is ignored when interrupt disable flag is set.
    if (_getInterruptDisableFlag() == 1) return;

    _pushStack16Bit(_regPC);
    _pushStack(_regPS.toInt());

    _regPC = bus.cpuRead16Bit(0xfffe);
    _setInterruptDisableFlag(1);
    _setBreakCommandFlag(1);
  }

  void _handleNmiInterrupt() {
    _pushStack16Bit(_regPC);
    _pushStack(_regPS.toInt());

    // Set the interrupt disable flag to prevent further interrupts.
    _setInterruptDisableFlag(1);

    _regPC = bus.cpuRead16Bit(0xfffa);
    costCycles += 7;
  }

  void _handleResetInterrupt() {
    _regPC = bus.cpuRead16Bit(0xfffc);
    _regSP -= Int8(3);
    _setInterruptDisableFlag(1);

    costCycles += 7;
  }

  // external methods
  int getPC() => _regPC;
  int getSP() => _regSP.toInt();
  int getPS() => _regPS.toInt();
  int getACC() => _regA.toInt();
  int getX() => _regX.toInt();
  int getY() => _regY.toInt();

  void reset() {
    _handleResetInterrupt();
  }

  void triggerNmiInterrupt() {
    _handleNmiInterrupt();
  }

  void powerOn() {
    _regPC = 0x8000;
    _regSP = Int8(0xfd);
    _regPS = Int8(0x34);
    _regA = Int8(0);
    _regX = Int8(0);
    _regY = Int8(0);
  }
}

extension DebugExtension on CPU {
  String _getStatusOfAllRegisters() {
    return "C:${_getCarryFlag()}" +
        " Z:${_getZeroFlag()}" +
        " I:${_getInterruptDisableFlag()}" +
        " D:${_getDecimalModeFlag()}" +
        " B:${_getBreakCommandFlag()}" +
        " O:${_getOverflowFlag()}" +
        " N:${_getNegativeFlag()}" +
        " PC:${_regPC.toHex()}" +
        " SP:${_regSP.toHex()}" +
        " A:${_regA.toHex()}" +
        " X:${_regX.toHex()}" +
        " Y:${_regY.toHex()}";
  }
}
