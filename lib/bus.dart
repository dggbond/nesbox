import 'dart:typed_data';

import 'package:flutter_nes/cartridge.dart';
import 'package:flutter_nes/cpu.dart';
import 'package:flutter_nes/ppu.dart';
import 'package:flutter_nes/memory.dart';
import 'package:flutter_nes/util.dart';

// bus is used to communiate between hardwares
class BUS {
  CPU cpu;
  PPU ppu;
  Memory cpuRAM; // WRAM for cpu
  Memory ppuRAM; // VRAM for ppu
  Memory ppuPalettes;
  Cardtridge cardtridge;

  int cpuRead(int address) {
    // access work RAM
    if (address < 0x800) return cpuRAM.read(address);

    // access work RAM mirrors
    if (address < 0x2000) return cpuRAM.read(address % 0x800);

    // access PPU Registers
    if (address < 0x2008) {
      if (address == 0x2000) throw ("CPU can not read PPUCTRL register in PPU");
      if (address == 0x2001) throw ("CPU can not read PPUMASK register in PPU");
      if (address == 0x2002) return ppu.getPPUSTATUS();
      if (address == 0x2003) throw ("CPU can not read OAMADDR register in PPU");
      if (address == 0x2004) return ppu.getOAMDATA();
      if (address == 0x2005) throw ("CPU can not read PPUSCROLL register in PPU");
      if (address == 0x2006) throw ("CPU can not read PPUADDR register in PPU");
      if (address == 0x2007) return ppu.getPPUDATA();
    }

    // access PPU Registers mirrors
    if (address < 0x4000) return cpuRead(0x2000 + address % 0x0008);

    // access APU and joypad registers and ppu 0x4014;
    if (address < 4020) {
      if (address == 0x4014) throw ("CPU can not read OMADMA register in PPU");
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
      return cpuRAM.write(address, value);
    }

    // access work RAM mirrors
    if (address < 0x2000) {
      return cpuRAM.write(address % 0x800, value);
    }

    // access PPU Registers
    if (address < 0x2008) {
      if (address == 0x2000) return ppu.setPPUCTRL(value);
      if (address == 0x2001) return ppu.setPPUMASK(value);
      if (address == 0x2002) throw ("CPU can not write PPUSTATUS register");
      if (address == 0x2003) return ppu.settOAMADDR(value);
      if (address == 0x2004) return ppu.setOAMDATA(value);
      if (address == 0x2005) return ppu.setPPUSCROLL(value);
      if (address == 0x2006) return ppu.setPPUADDR(value);
      if (address == 0x2007) return ppu.setPPUDATA(value);
    }

    // access PPU Registers mirrors
    if (address < 0x4000) {
      return cpuWrite(0x2000 + address % 0x0008, value);
    }

    // APU and joypad registers and ppu 0x4014;
    if (address < 4020) {
      if (address == 0x4014) return ppu.setOMADMA(value);
    }

    // Expansion ROM
    if (address < 0x6000) {}

    // SRAM
    if (address < 0x8000) {}

    // PRG ROM
    if (address < 0x10000) {
      throw ("cpu writing: can't write PRG-ROM at address ${address.toHex()}.");
    }

    throw ("cpu writing: address ${address.toHex()} is over memory map size.");
  }

  int cpuRead16Bit(int address) {
    return cpuRead(address + 1) << 2 & cpuRead(address);
  }

  int ppuRead(int address) {
    // CHR-ROM or Pattern Tables
    if (address < 0x2000) return cardtridge.readCHR(address);

    // NameTables (RAM)
    if (address < 0x3000) {
      // horizontal mirroring
      // [1][1] --> [0x2000][0x2400]
      // [2][2] --> [0x2800][0x2c00]
      if (cardtridge.mirroring == 0) {
        // mirroring to 0x2000 area
        if (address >= 0x2400 && address < 0x2800) {
          return ppuRAM.read(0x2000 + address % 0x400);
        }

        // mirroring to 0x2800 area
        if (address >= 0x2c00) {
          return ppuRAM.read(0x2800 + address % 0x400);
        }
      }

      // vertical mirroring
      // [1][2] --> [0x2000][0x2400]
      // [1][2] --> [0x2800][0x2c00]
      if (cardtridge.mirroring == 1) {
        // mirroring to 0x2000 area
        if (address >= 0x2800 && address < 0x2c00) {
          return ppuRAM.read(0x2000 + address % 0x400);
        }

        // mirroring to 0x2800 area
        if (address >= 0x2c00) {
          return ppuRAM.read(0x2400 + address % 0x400);
        }
      }

      return ppuRAM.read(address - 0x2000);
    }

    // NameTables Mirrors
    if (address < 0x3f00) return ppuRead(0x2000 + address % 0x1000);

    // Palettes
    if (address < 0x3f20) return ppuPalettes.read(address - 0x3f00);

    // Palettes Mirrors
    if (address < 0x4000) return ppuRead(0x3f00 + address % 0x20);

    // whole Mirrors
    if (address < 0x10000) return ppuRead(address % 0x4000);

    throw ("ppu reading: address ${address.toHex()} is over memory map size.");
  }

  Uint8List ppuReadBank(int address, int bankSize) {
    return Uint8List.fromList(Iterable.generate(bankSize).map((i) => ppuRead(address + i)).toList());
  }

  void ppuWrite(int address, int value) {
    // CHR-ROM or Pattern Tables
    if (address < 0x2000) return cardtridge.wirteCHR(address, value);

    // NameTables (RAM)
    if (address < 0x3000) return ppuRAM.write(address - 0x2000, value);

    // NameTables Mirrors
    if (address < 0x3f00) throw ("ppu writing: not allowed to write name tables mirrors.");

    // Palettes
    if (address < 0x3f20) return ppuPalettes.write(address - 0x3f00, value);

    // Palettes Mirrors
    if (address < 0x4000) throw ("ppu writing: not allowed to write palettes mirrors.");

    // whole Mirrors
    if (address < 0x10000) throw ("ppu writing: not allowed to write mirrors.");

    throw ("cpu writing: address ${address.toHex()} is over memory map size.");
  }
}
