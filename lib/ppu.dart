import 'package:flutter_nes/memory.dart';
import 'package:flutter_nes/bus.dart';
import 'package:flutter_nes/rom.dart';
import 'package:flutter_nes/util.dart';

List<int> combinePatterns(List<int> left, List<int> right) {}

class NesPpu {
  NesPpu([this.bus]);

  NesPpuMemory _memory = NesPpuMemory();
  NesBus bus;

  // only write
  set _regPPUCTRL(Int8 value) {
    bus.writeCpuMemory(0x2000, value.value);
  }

  // only write
  set _regPPUMASK(Int8 value) {
    bus.writeCpuMemory(0x2001, value.value);
  }

  // only read, but this should be set when power up or reset.
  Int8 get _regPPUSTATUS => Int8(bus.readCpuMemory(0x2002));
  set _regPPUSTATUS(Int8 value) {
    bus.writeCpuMemory(0x2002, value.value);
  }

  // only write
  set _regOAMADDR(Int8 value) {
    bus.writeCpuMemory(0x2003, value.value);
  }

  // only write
  set _regOAMDATA(Int8 value) {
    bus.writeCpuMemory(0x2004, value.value);
  }

  // only write
  set _regPPUSCROLL(Int8 value) {
    bus.writeCpuMemory(0x2005, value.value);
  }

  // only write
  set _regPPUADDR(Int8 value) {
    bus.writeCpuMemory(0x2006, value.value);
  }

  // read/write
  Int8 get _regPPUDATA => Int8(bus.readCpuMemory(0x2007));
  set _regPPUDATA(Int8 value) {
    bus.writeCpuMemory(0x2007, value.value);
  }

  // only write
  set _regOMADMA(Int8 value) {
    bus.writeCpuMemory(0x4014, value.value);
  }

  void powerOn() {
    _regPPUCTRL = Int8(0x00);
    _regPPUMASK = Int8(0x00);
    _regPPUSTATUS = Int8(0xa0); // 1010 0000
    _regOAMADDR = Int8(0x00);
    _regPPUSCROLL = Int8(0x00);
    _regPPUADDR = Int8(0x00);
    _regPPUDATA = Int8(0x00);

    // fill the pattern table
    if (bus.rom.chrNum == 1) {
      int chrStart = NesRom.HEADER_SIZE + bus.rom.trainerSize + bus.rom.chrNum * NesRom.PRG_ROM_BANK_SIZE;

      _memory.writeBytes(NesPpuMemory.PATTERN_TABLE_RANGE, bus.readRomBytes([chrStart, chrStart + NesRom.CHR_ROM_BANK_SIZE]));
    }
  }

  void reset() {
    // PPUADDE register is unchange
    _regPPUCTRL = Int8(0x00);
    _regPPUMASK = Int8(0x00);
    _regPPUSTATUS = Int8(_regPPUSTATUS.getBit(7) << 7);
    _regOAMADDR = Int8(0x00);
    _regPPUSCROLL = Int8(0x00);
    _regPPUDATA = Int8(0x00);
  }
}
