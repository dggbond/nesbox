library flutter_nes;

import 'dart:convert';
import "dart:typed_data";

import 'package:flutter_nes/util.dart';

class NesROM {
  NesROM(Uint8List rom) {
    _parseHeader(rom);
  }

  Uint8List _prgROM; // PRG-ROM(Program ROM), all the program code is here.
  int mirroring;

  // program counter
  int readProgram(int pc) {
    return _prgROM[pc];
  }

  _parseHeader(Uint8List rom) {
    if (utf8.decode(rom.sublist(0, 3)) != "NES") {
      throw ("parse iNES file failed. the first 3 bytes is not the string `NES`");
    }

    if (rom.elementAt(3) != 0x1a) {
      throw ("parse iNES file failed. the fourth byte is not the value \$1a");
    }

    int prgROMBanks = rom.elementAt(4);
    int chrROMBanks = rom.elementAt(5);

    int controlByte1 = rom.elementAt(6);

    mirroring = controlByte1.getBit(0);

    int controlByte2 = rom.elementAt(7);
  }
}
