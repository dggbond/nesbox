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
  static const int CHR_ROM_BANK_SIZE = 0x2000; // 8 kb

  Uint8List _rom; // original rom data.

  // Size of PRG ROM in 16 KB units
  int prgNum;

  // Size of CHR ROM in 8 KB units (Value 0 means the board uses CHR RAM)
  int chrNum;

  // 0: horizontal (vertical arrangement) (CIRAM A10 = PPU A11)
  // 1: vertical (horizontal arrangement) (CIRAM A10 = PPU A10)
  int mirroring;

  // 1: 512-byte trainer at $7000-$71FF (stored before PRG data)
  int trainerSize;

  // 1: Ignore mirroring control or above mirroring bit; instead provide four-screen VRAM
  int ignoreMirroring;

  // memory mapper number
  int mapperNumber;

  // NES 2.0 format
  bool isNES2;

  // TV system (0: NTSC; 1: PAL)
  int tvSystem;

  Uint8List readBytes(List<int> range) {
    return _rom.sublist(range[0], range[1]);
  }

  _parseHeader() {
    // see: https://wiki.nesdev.com/w/index.php/INES
    // 0-3: Constant $4E $45 $53 $1A ("NES" followed by MS-DOS end-of-file)
    if (!listEquals(_rom.sublist(0, 4), Uint8List.fromList([0x4e, 0x45, 0x53, 0x1a]))) {
      throw ("the first 4 bytes not equals to the nes identify");
    }

    prgNum = _rom.elementAt(4);
    chrNum = _rom.elementAt(5);

    int flags6 = _rom.elementAt(6);

    mirroring = flags6.getBit(0);
    trainerSize = flags6.getBit(2) * TRAINER_SIZE;
    ignoreMirroring = flags6.getBit(3);

    int flags7 = _rom.elementAt(7);

    isNES2 = flags7.getBit(2) << 1 | flags7.getBit(1) == 2;

    mapperNumber = (flags7 & 0xf0) | (flags6 & 0xf0) >> 4;

    if (isNES2) {
      _parseNES2();
      return;
    }
  }

  // @TODO: parse the NES 2.0 format header
  _parseNES2() {
    print("this is a nes 2.0 file");
  }
}
