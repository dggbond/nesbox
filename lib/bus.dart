import 'dart:typed_data';

import 'cartridge.dart';
import 'cpu.dart';
import 'ppu.dart';

// bus is used to communiate between hardwares
class BUS {
  BUS() {
    cpu.bus = this;
    ppu.bus = this;
  }

  CPU cpu = CPU();
  PPU ppu = PPU();
  Uint8List cpuWorkRAM = Uint8List(0x800);

  // In most case PPU only use 2kb RAM and mirroring the name tables
  // but when four-screen mirroring it will use an additional 2kb RAM.
  // In this emulator, i ignore four-screen case, so i just need 2kb RAM.
  Uint8List ppuVideoRAM0 = Uint8List(0x400);
  Uint8List ppuVideoRAM1 = Uint8List(0x400);
  Uint8List ppuPalettes = Uint8List(0x20);
  Cardtridge card = Cardtridge();

  int cpuRead(int address) {
    address &= 0xffff;

    // [0x0000, 0x0800] is RAM, [0x0800, 0x02000] is mirrors
    if (address < 0x2000) {
      return cpuWorkRAM[address % 0x800];
    } else if (address < 0x4000) {
      if (address == 0x2000) return ppu.regCTRL;
      if (address == 0x2001) return ppu.getPPUMASK();
      if (address == 0x2002) return ppu.getPPUSTATUS();
      if (address == 0x2003) return ppu.getOAMADDR();
      if (address == 0x2004) return ppu.getOAMDATA();
      if (address == 0x2005) return 0;
      if (address == 0x2006) return 0;
      if (address == 0x2007) return ppu.getPPUDATA();
    } else if (address < 4020) {
      if (address == 0x4014) return 0;
      return 0;

      // Expansion ROM
    } else if (address < 0x6000) {
      return 0;

      // SRAM
    } else if (address < 0x8000) {
      if (card.sRAM != null) {
        return card.sRAM[address - 0x6000];
      }
      return 0;

      // PRG ROM
    } else if (address < 0x10000) {
      return card.readPRG(address - 0x8000);
    }

    return 0;
  }

  void cpuWrite(int address, int value) {
    address &= 0xffff;

    // write work RAM & mirrors
    if (address < 0x2000) {
      cpuWorkRAM[address % 0x800] = value;
    } else if (address < 0x4000) {
      address = (address - 0x2000) % 0x0008;

      if (address == 0x00) {
        ppu.setPPUCTRL(value);
      } else if (address == 0x01) {
        ppu.setPPUMASK(value);
      } else if (address == 0x02) {
        throw ("CPU can not write PPUSTATUS register");
      } else if (address == 0x03) {
        ppu.setOAMADDR(value);
      } else if (address == 0x04) {
        ppu.setOAMDATA(value);
      } else if (address == 0x05) {
        ppu.setPPUSCROLL(value);
      } else if (address == 0x06) {
        ppu.setPPUADDR(value);
      } else if (address == 0x07) {
        ppu.setPPUDATA(value);
      }

      // APU and joypad registers and ppu 0x4014;
    } else if (address < 4020) {
      if (address == 0x4014) {
        ppu.setOAMDMA(value);
        cpu.cycles += 514;
      }

      // Expansion ROM
    } else if (address < 0x6000) {
      // SRAM
    } else if (address < 0x8000) {
      if (card.sRAM != null) {
        card.sRAM[address - 0x6000] = value;
      }

      // PRG ROM
    } else if (address < 0x10000) {}
  }

  int ppuRead(int address) {
    address = (address & 0xffff) % 0x4000;

    // CHR-ROM or Pattern Tables
    if (address < 0x2000) {
      return card.readCHR(address);

      // NameTables (RAM)
    } else if (address < 0x3f00) {
      address = 0x2000 + address % 0x1000;

      // horizontal mirroring
      // [1][1] --> [0x2000][0x2400]
      // [2][2] --> [0x2800][0x2c00]
      if (card.mirroring == Mirroring.Horizontal) {
        if (address < 0x2800) {
          return ppuVideoRAM0[address % 0x400];
        } else {
          return ppuVideoRAM1[address % 0x400];
        }
      }

      // vertical mirroring
      // [1][2] --> [0x2000][0x2400]
      // [1][2] --> [0x2800][0x2c00]
      if (card.mirroring == Mirroring.Vertical) {
        if (address < 0x2400 || (address >= 0x2800 && address < 0x2c00)) {
          return ppuVideoRAM0[address % 0x400];
        } else {
          return ppuVideoRAM1[address % 0x400];
        }
      }

      // Palettes
    } else if (address < 0x4000) {
      address = (address - 0x3f00) % 0x20;
      return ppuPalettes[address];
    }

    return 0;
  }

  void ppuWrite(int address, int value) {
    address = (address & 0xffff) % 0x4000;

    // CHR-ROM or Pattern Tables
    if (address < 0x2000) {
      card.writeCHR(address, value);

      // NameTables (RAM)
    } else if (address < 0x3f00) {
      address = 0x2000 + address % 0x1000;

      // horizontal mirroring
      // [1][1] --> [0x2000][0x2400]
      // [2][2] --> [0x2800][0x2c00]
      if (card.mirroring == Mirroring.Horizontal) {
        // mirroring to 0x2000 area
        if (address < 0x2800) {
          ppuVideoRAM0[address % 0x400] = value;
        } else {
          ppuVideoRAM1[address % 0x400] = value;
        }
      }

      // vertical mirroring
      // [1][2] --> [0x2000][0x2400]
      // [1][2] --> [0x2800][0x2c00]
      if (card.mirroring == Mirroring.Vertical) {
        // mirroring to 0x2000 area
        if (address < 0x2400 || (address >= 0x2800 && address < 0x2c00)) {
          ppuVideoRAM0[address % 0x400] = value;
        } else {
          ppuVideoRAM1[address % 0x400] = value;
        }
      }

      // Palettes
    } else if (address < 0x4000) {
      address = (address - 0x3f00) % 0x20;
      ppuPalettes[address] = value;
    }
  }
}
