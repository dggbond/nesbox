import "dart:typed_data";

import "package:flutter_nes/util.dart";

class Cardtridge {
  static const int PRG_BANK_SIZE = 0x4000;
  static const int CHR_BANK_SIZE = 0x2000;
  static const int TRAINER_SIZE = 0x0200;

  Uint8List rom; // ines rom file data
  Uint8List prgROM;
  Uint8List chrROM;
  Uint8List trainerROM;

  bool isNES2() {
    return rom.elementAt(7).getBits(1, 2) == 2;
  }

  int get prgNum => rom.elementAt(4);
  int get chrNum => rom.elementAt(5);
  int get trainerNum => rom.elementAt(6).getBit(2);

  // 0: horizontal (vertical arrangement) (CIRAM A10 = PPU A11)
  // 1: vertical (horizontal arrangement) (CIRAM A10 = PPU A10)
  int get mirroring => rom.elementAt(6).getBit(0);

  int get _prgStart => 0x10 + trainerNum * TRAINER_SIZE;
  int get _chrStart => _prgStart + prgNum * PRG_BANK_SIZE;

  loadGame(Uint8List data) {
    // see: https://wiki.nesdev.com/w/index.php/INES
    // 0-3: Constant $4E $45 $53 $1A ("NES" followed by MS-DOS end-of-file)
    if (!data.sublist(0, 4).equalsTo([0x4e, 0x45, 0x53, 0x1a])) {
      throw ("the first 4 bytes not equals to the nes identify");
    }

    rom = data;

    if (trainerNum == 1) {
      trainerROM = data.sublist(0x0010, 0x0010 + TRAINER_SIZE);
    }

    prgROM = data.sublist(_prgStart, _prgStart + prgNum * PRG_BANK_SIZE);
    chrROM = data.sublist(_chrStart, _chrStart + chrNum * CHR_BANK_SIZE);
  }

  int readPRG(int address) => prgROM.elementAt(address);
  int readCHR(int address) => chrROM.elementAt(address);
  void wirteCHR(int address, int value) => chrROM[address] = value;
}
