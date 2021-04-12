import "dart:typed_data";

import "package:flutter/foundation.dart";
import "package:flutter_nes/util.dart";

class NesRom {
  NesRom(this._rom) {
    try {
      _parseHeader();
    } catch (err) {
      throw ("parse header failed. $err");
    }
  }

  static const int HEADER_SIZE = 0x0f; // 16 bytes
  static const int TRAINER_SIZE = 0x200; // 512 bytes
  static const int PRG_ROM_BANK_SIZE = 0x4000; // 16 kb

  Uint8List _rom; // PRG-ROM(Program ROM), all the program code is here.

  // Size of PRG ROM in 16 KB units
  int prgROMSize;

  // Size of CHR ROM in 8 KB units (Value 0 means the board uses CHR RAM)
  int chrROMSize;

  // Size of PRG RAM in 8 KB units
  int prgRAMSize;

  // 0: horizontal (vertical arrangement) (CIRAM A10 = PPU A11)
  // 1: vertical (horizontal arrangement) (CIRAM A10 = PPU A10)
  int mirroringFlag;

  // 1: Cartridge contains battery-backed PRG RAM ($6000-7FFF) or other persistent memory
  int batteryFlag;

  // 1: 512-byte trainer at $7000-$71FF (stored before PRG data)
  int trainerFlag;

  // 1: Ignore mirroring control or above mirroring bit; instead provide four-screen VRAM
  int ignoreMirroringFlag;

  // memory mapper number
  int mapperNumber;

  int prgStartAt;

  // VS Unisystem
  int vsUnisystemFlag;

  // PlayChoice-10 (8KB of Hint Screen data stored after CHR data)
  int playChoice10Flag;

  // NES 2.0 format
  bool isNES2;

  // TV system (0: NTSC; 1: PAL)
  int tvSystem;

  Uint8List readBytes(int start, int end) {
    return _rom.sublist(start, end);
  }

  _parseHeader() {
    // see: https://wiki.nesdev.com/w/index.php/INES
    // 0-3: Constant $4E $45 $53 $1A ("NES" followed by MS-DOS end-of-file)
    if (!listEquals(_rom.sublist(0, 4), Uint8List.fromList([0x4e, 0x45, 0x53, 0x1a]))) {
      throw ("the first 4 bytes not equals to the nes identify");
    }

    prgROMSize = _rom.elementAt(4);
    chrROMSize = _rom.elementAt(5);

    int flags6 = _rom.elementAt(6);

    mirroringFlag = flags6.getBit(0);
    batteryFlag = flags6.getBit(1);
    trainerFlag = flags6.getBit(2);
    ignoreMirroringFlag = flags6.getBit(3);

    int flags7 = _rom.elementAt(7);

    vsUnisystemFlag = flags7.getBit(0);
    playChoice10Flag = flags7.getBit(1);
    isNES2 = flags7.getBit(2) << 1 | flags7.getBit(1) == 2;

    mapperNumber = (flags7 & 0xf0) | (flags6 & 0xf0) >> 4;

    prgStartAt = trainerFlag == 1 ? HEADER_SIZE + TRAINER_SIZE : HEADER_SIZE;

    if (isNES2) {
      _parseNES2();
      return;
    }

    // flags8
    prgRAMSize = _rom.elementAt(8);

    // 1-7 bits in flags9 is reserved, set to zero
    int flags9 = _rom.elementAt(9);
    tvSystem = flags9.getBit(0);

    // This byte is not part of the official specification, and relatively few emulators honor it.
    // int flags10 = _rom.elementAt(10);
    //
    // byte 11-15: Unused padding (should be filled with zero, but some rippers put their name across bytes 7-15)
  }

  // @TODO: parse the NES 2.0 format header
  _parseNES2() {
    print("this is a nes 2.0 file");
  }
}
