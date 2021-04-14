import 'dart:typed_data';

import 'package:flutter_nes/cartridge.dart';
import 'package:flutter_nes/cpu.dart';
import 'package:flutter_nes/ppu.dart';
import 'package:flutter_nes/ram.dart';
import 'package:flutter_nes/util.dart';

// bus is used to communiate between hardwares
class BUS {
  CPU cpu;
  PPU ppu;
  RAM cpuRAM; // WRAM for cpu
  RAM ppuRAM; // VRAM for ppu
  Cardtridge cardtridge;

  int cpuRead(int address) {
    // access work RAM
    if (address < 0x800) return cpuRAM.read(address);

    // access work RAM mirrors
    if (address < 0x2000) return cpuRAM.read(address % 0x800);

    // access PPU Registers
    if (address < 0x2008) {
      if (address == 0x2000) return ppu.regPPUCTRL.value;
      if (address == 0x2001) return ppu.regPPUMASK.value;
      if (address == 0x2002) return ppu.regPPUSTATUS.value;
      if (address == 0x2003) return ppu.regOAMADDR.value;
      if (address == 0x2004) return ppu.regOAMDATA.value;
      if (address == 0x2005) return ppu.regPPUSCROLL.value;
      if (address == 0x2006) return ppu.regPPUADDR.value;
      if (address == 0x2007) return ppu.regPPUDATA.value;
    }

    // access PPU Registers mirrors
    if (address < 0x4000) return cpuRead(0x2000 + address % 0x0008);

    // access APU and joypad registers and ppu 0x4014;
    if (address < 4020) {
      if (address == 0x4014) return ppu.regOMADMA.value;
    }

    // Expansion ROM
    if (address < 0x6000) {}

    // SRAM
    if (address < 0x8000) {}

    // PRG ROM
    if (address < 0x10000) {
      return cardtridge.readPRG(address - 0x8000);
    }

    throw ("cpu reading: address ${address.toHex()} is over memory map size.");
  }

  void cpuWrite(int address, int value) {
    // write work RAM
    if (address < 0x800) {
      cpuRAM.write(address, value);
    }
  }

  int cpuRead16Bit(int address) {
    return cpuRead(address + 1) << 2 & cpuRead(address);
  }
}
