library flutter_nes.bus;

import 'dart:typed_data';

import 'cartridge.dart';
import 'cpu/cpu.dart';
import 'ppu.dart';
import 'util/util.dart';

// bus is used to communiate between hardwares
class BUS {
  BUS() {
    cpu.bus = this;
    ppu.bus = this;
  }

  CPU cpu = CPU();
  PPU ppu = PPU();
  Cardtridge card = Cardtridge();

  Uint8List cpuWorkRAM;
  // In most case PPU only use 2kb RAM and mirroring the name tables
  // but when four-screen mirroring it will use an additional 2kb RAM.
  // In this emulator, i ignore four-screen case, so i just need 2kb RAM.
  Uint8List ppuVideoRAM;
  Uint8List ppuPalettes;

  int cpuRead(int address) {
    address &= 0xffff;

    // [0x0000, 0x0800] is RAM, [0x0800, 0x02000] is mirrors
    if (address < 0x2000) {
      return cpuWorkRAM[address % 0x800];
    }

    if (address < 0x4000) {
      address = 0x2000 + address % 0x08;

      if (address == 0x2002) return ppu.regStatus;
      if (address == 0x2004) return ppu.regOamData;
      if (address == 0x2007) return ppu.regData;

      throw "Unhandled register reading: ${address.toHex()}";
    }

    // TODO: apu registers;
    if (address < 0x4020) {
      if (address == 0x4004) return 0xff;
      if (address == 0x4005) return 0xff;
      if (address == 0x4006) return 0xff;
      if (address == 0x4007) return 0xff;
      if (address == 0x4015) return 0xff;

      return 0;
    }

    // Expansion ROM
    if (address < 0x6000) return 0;

    // SRAM
    if (address < 0x8000) return card.read(address);

    // PRG ROM
    return card.read(address);
  }

  void cpuWrite(int address, int value) {
    address &= 0xffff;
    value &= 0xff;

    // write work RAM & mirrors
    if (address < 0x2000) {
      cpuWorkRAM[address % 0x800] = value;
      return;
    }

    // write ppu registers
    if (address < 0x4000 || address == 0x4014) {
      if (address == 0x4014) {
        ppu.regDMA = value;
        cpu.cycles += ppu.fOddFrames ? 514 : 513;
        return;
      }

      address = 0x2000 + address % 0x08;

      if (address == 0x2000) {
        ppu.regController = value;
        return;
      }
      if (address == 0x2001) {
        ppu.regMask = value;
        return;
      }
      if (address == 0x2003) {
        ppu.regOamAddress = value;
        return;
      }
      if (address == 0x2004) {
        ppu.regOamData = value;
        return;
      }
      if (address == 0x2005) {
        ppu.regScroll = value;
        return;
      }
      if (address == 0x2006) {
        ppu.regAddress = value;
        return;
      }
      if (address == 0x2007) {
        ppu.regData = value;
        return;
      }

      throw "Unhandled register writing: ${address.toHex()}";
    }

    // APU and joypad registers and ppu 0x4014;
    if (address < 0x4020) {
      return;
      // throw "Unhandled register writing: ${address.toHex()}";
    }

    // Expansion ROM
    if (address < 0x6000) return;

    if (address < 0x8000) {
      if (card.battery) card.sRAM[address - 0x6000] = value;
      return;
    }

    // PRG ROM
    card.write(address, value);
  }

  int ppuRead(int address) {
    address = (address & 0xffff) % 0x4000;

    // CHR-ROM or Pattern Tables
    if (address < 0x2000) return card.read(address);

    // NameTables (RAM)
    if (address < 0x3f00) return ppuVideoRAM[nameTableMirroring(address)];

    // Palettes
    return ppuPalettes[address % 0x20];
  }

  void ppuWrite(int address, int value) {
    address = (address & 0xffff) % 0x4000;
    value &= 0xff;

    // CHR-ROM or Pattern Tables
    if (address < 0x2000) {
      card.write(address, value);
      return;
    }

    // NameTables (RAM)
    if (address < 0x3f00) {
      ppuVideoRAM[nameTableMirroring(address)] = value;
      return;
    }

    // Palettes
    ppuPalettes[address % 0x20] = value;
  }

  int nameTableMirroring(int address) {
    address = address % 0x1000;
    int chunk = (address / 0x400).floor() + 1;

    switch (card.mirroring) {
      // [1][1] --> [0x2000][0x2400]
      // [2][2] --> [0x2800][0x2c00]
      case Mirroring.Horizontal:
        return [2, 4].contains(chunk) ? address - 0x400 : address;

      // [1][2] --> [0x2000][0x2400]
      // [1][2] --> [0x2800][0x2c00]
      case Mirroring.Vertical:
        return chunk > 2 ? address - 0x800 : address;

      // [1][2] --> [0x2000][0x2400]
      // [3][4] --> [0x2800][0x2c00]
      case Mirroring.FourScreen:
        return address;

      // [1][1] --> [0x2000][0x2400]
      // [1][1] --> [0x2800][0x2c00]
      case Mirroring.SingleScreen:
        return address % 0x400;
    }

    return address;
  }

  reset() {
    cpuWorkRAM = Uint8List(0x800);
    ppuPalettes = Uint8List(0x20);
    ppuVideoRAM = card.mirroring == Mirroring.FourScreen ? Uint8List(0x1000) : Uint8List(0x800);
  }
}
