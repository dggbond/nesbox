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
  int _regSP = 0; // Stack Pointer register
  int _regPS = 0; // Processor Status register
  int _regACC = 0; // Accumulator register
  int _regX = 0; // Index register, used for indexed addressing mode
  int _regY = 0; // Index register

  // execute one instruction
  emulate(Op op, Int8List nextBytes) {
    int value;
    int extraCycles;

    switch (op.addrMode) {
      case AddrMode.ZeroPage:
        value = _memory.read(nextBytes[0]);
        break;

      case AddrMode.ZeroPageX:
        value = _memory.read(nextBytes[0] + _regX);
        break;

      case AddrMode.ZeroPageY:
        value = _memory.read(nextBytes[0] + _regY);
        break;

      case AddrMode.Absolute:
        value = _memory.read(nextBytes[1] << 2 + nextBytes[0]);
        break;

      case AddrMode.AbsoluteX:
        value = _memory.read(nextBytes[1] << 2 + nextBytes[0] + _regX);
        break;

      case AddrMode.AbsoluteY:
        value = _memory.read(nextBytes[1] << 2 + nextBytes[0] + _regY);
        break;

      case AddrMode.Indirect:
        int absoluteAddr = nextBytes[1] << 2 + nextBytes[0];
        int addr = _memory.read(absoluteAddr + 1) << 2 + _memory.read(absoluteAddr);
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
        int addr = _memory.read(nextBytes[0] + _regX + 1) << 2 + _memory.read(nextBytes[0] + _regX);
        value = _memory.read(addr);
        break;

      case AddrMode.IndirectY:
        int addr = _memory.read(nextBytes[0] + _regY + 1) << 2 + _memory.read(nextBytes[0] + _regY);
        value = _memory.read(addr);
        break;

      case AddrMode.IndirectIndexed:
        int addr = _memory.read(nextBytes[0] + 1) << 2 + _memory.read(nextBytes[0]) + _regY;
        value = _memory.read(addr);
        break;

      default:
        throw ('cpu emulate: ${op.addrMode} is an unknown addressing mode.');
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

        _setCarryFlag(Int8Util.isOverMax(result));
        _setZeroFlag(Int8Util.isZero(result));
        _setNegativeFlag(Int8Util.isNegative(result));

        _regACC = result & 0xff;
        break;

      case InsEnum.AND:

      default:
        throw ('cpu emulate: ${op.ins} is an unknown instruction.');
    }

    _regPC += op.bytes;
  }

  int getPC() {
    return _regPC;
  }

  // get flags
  int _getCarryFlag() {
    return Int8Util.getBitValue(_regPS, 0);
  }

  void _setCarryFlag(int value) {
    _regPS = Int8Util.setBitValue(_regPS, 0, value);
  }

  int _getZeroFlag() {
    return Int8Util.getBitValue(_regPS, 1);
  }

  void _setZeroFlag(int value) {
    _regPS = Int8Util.setBitValue(_regPS, 1, value);
  }

  int _getInterruptDisableFlag() {
    return Int8Util.getBitValue(_regPS, 2);
  }

  void _setInterruptDisableFlag(int value) {
    _regPS = Int8Util.setBitValue(_regPS, 2, value);
  }

  int _getDecimalModeFlag() {
    return Int8Util.getBitValue(_regPS, 3);
  }

  void _setDecimalModeFlag(int value) {
    _regPS = Int8Util.setBitValue(_regPS, 3, value);
  }

  int _getBreakCommandFlag() {
    return Int8Util.getBitValue(_regPS, 4);
  }

  void _setBreakCommandFlag(int value) {
    _regPS = Int8Util.setBitValue(_regPS, 4, value);
  }

  int _getOverflowFlag() {
    return Int8Util.getBitValue(_regPS, 6);
  }

  void _setOverflowFlag(int value) {
    _regPS = Int8Util.setBitValue(_regPS, 6, value);
  }

  int _getNegativeFlag() {
    return Int8Util.getBitValue(_regPS, 7);
  }

  void _setNegativeFlag(int value) {
    _regPS = Int8Util.setBitValue(_regPS, 7, value);
  }
}
