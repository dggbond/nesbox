import 'dart:typed_data';

import 'cartridge.dart';
import 'cpu.dart';
import 'ppu.dart';
import 'memory.dart';
import 'util/util.dart';

// bus is used to communiate between hardwares
class BUS {
  BUS() {
    cpu.bus = this;
    ppu.bus = this;
  }

  CPU cpu = CPU();
  PPU ppu = PPU();
  Memory cpuWorkRAM = Memory(0x800);

  // In most case PPU only use 2kb RAM and mirroring the name tables
  // but when four-screen mirroring it will use an additional 2kb RAM.
  // In this emulator, i ignore four-screen case, so i just need 2kb RAM.
  Memory ppuVideoRAM = Memory(0x800);
  Memory ppuPalettes = Memory(0x20);
  Cardtridge cardtridge = Cardtridge();

  int dmaCycles = 0;

  int cpuRead(int address) {
    address &= 0xffff;

    // [0x0000, 0x0800] is RAM, [0x0800, 0x02000] is mirrors
    if (address < 0x2000) return cpuWorkRAM.read(address % 0x800);

    // access PPU Registers
    if (address == 0x2000) return ppu.getPPUCTRL();
    if (address == 0x2001) return ppu.getPPUMASK();
    if (address == 0x2002) return ppu.getPPUSTATUS();
    if (address == 0x2003) return 0;
    if (address == 0x2004) return ppu.getOAMDATA();
    if (address == 0x2005) return 0;
    if (address == 0x2006) return 0;
    if (address == 0x2007) return ppu.getPPUDATA();

    // access PPU Registers mirrors
    if (address < 0x4000) return cpuRead(0x2000 + address % 0x0008);

    // access APU and joypad registers and ppu 0x4014;
    if (address < 4020) {
      if (address == 0x4014) return 0;
    }

    // Expansion ROM
    if (address < 0x6000) {
      return 0;
    }

    // SRAM
    if (address < 0x8000) {
      if (cardtridge.sRAM != null) {
        return cardtridge.sRAM.read(address - 0x6000);
      } else {
        return 0;
      }
    }

    // PRG ROM
    if (address < 0x10000) {
      return cardtridge.readPRG(address - 0x8000);
    }

    throw ("cpu reading: address ${address.toRadixString(16)} is over memory map size.");
  }

  void cpuWrite(int address, int value) {
    address &= 0xffff;

    // write work RAM
    if (address < 0x800) {
      return cpuWorkRAM.write(address, value);
    }

    // access work RAM mirrors
    if (address < 0x2000) {
      return cpuWorkRAM.write(address % 0x800, value);
    }

    // access PPU Registers
    if (address == 0x2000) return ppu.setPPUCTRL(value);
    if (address == 0x2001) return ppu.setPPUMASK(value);
    if (address == 0x2002) throw ("CPU can not write PPUSTATUS register");
    if (address == 0x2003) return ppu.setOAMADDR(value);
    if (address == 0x2004) return ppu.setOAMDATA(value);
    if (address == 0x2005) return ppu.setPPUSCROLL(value);
    if (address == 0x2006) return ppu.setPPUADDR(value);
    if (address == 0x2007) return ppu.setPPUDATA(value);

    // access PPU Registers mirrors
    if (address < 0x4000) {
      return cpuWrite(0x2000 + address % 0x0008, value);
    }

    // APU and joypad registers and ppu 0x4014;
    if (address < 4020) {
      if (address == 0x4014) {
        ppu.setOAMDMA(value);
        dmaCycles = 514;
        return;
      }
    }

    // Expansion ROM
    if (address < 0x6000) {
      return;
    }

    // SRAM
    if (address < 0x8000) {
      if (cardtridge.sRAM != null) {
        cardtridge.sRAM.write(address - 0x6000, value);
      }
      return;
    }

    // PRG ROM
    if (address < 0x10000) {
      throw ("cpu writing: can't write PRG-ROM at address ${address.toHex()}.");
    }

    throw ("cpu writing: address ${address.toRadixString(16)} is over memory map size.");
  }

  int cpuRead16Bit(int address) {
    return cpuRead(address + 1) << 8 | cpuRead(address);
  }

  int ppuRead(int address) {
    address &= 0xffff;

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
          return ppuRead(0x2000 + address % 0x400);
        }

        // mirroring to 0x2800 area
        if (address >= 0x2c00) {
          return ppuRead(0x2800 + address % 0x400);
        }
      }

      // vertical mirroring
      // [1][2] --> [0x2000][0x2400]
      // [1][2] --> [0x2800][0x2c00]
      if (cardtridge.mirroring == 1) {
        // mirroring to 0x2000 area
        if (address >= 0x2800 && address < 0x2c00) {
          return ppuRead(0x2000 + address % 0x400);
        }

        // mirroring to 0x2800 area
        if (address >= 0x2c00) {
          return ppuRead(0x2400 + address % 0x400);
        }
      }

      return ppuVideoRAM.read(address - 0x2000);
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
    address &= 0xffff;

    var data = Uint8List(bankSize);
    for (int i = 0; i < bankSize; i++) {
      data[i] = ppuRead(address + i);
    }

    return data;
  }

  void ppuWrite(int address, int value) {
    address &= 0xffff;

    // CHR-ROM or Pattern Tables
    if (address < 0x2000) return cardtridge.writeCHR(address, value);

    // NameTables (RAM)
    if (address < 0x3000) return ppuVideoRAM.write(address - 0x2000, value);

    // NameTables Mirrors
    if (address < 0x3f00) return ppuWrite(0x2000 + (address - 0x3000) % 0xf00, value);

    // Palettes
    if (address < 0x3f20) {
      return ppuPalettes.write(address - 0x3f00, value);
    }

    // Palettes Mirrors
    if (address < 0x4000) return ppuWrite(0x3f00 + (address - 0x3f20) % 0x20, value);

    // whole Mirrors
    if (address < 0x10000) return ppuWrite(address % 0x4000, value);

    throw ("cpu writing: address ${address.toHex()} is over memory map size.");
  }
}
