import "dart:typed_data";

import "memory.dart";
import 'util/util.dart';

const int PRG_BANK_SIZE = 0x4000;
const int CHR_BANK_SIZE = 0x2000;
const int TRAINER_SIZE = 0x0200;

enum Mirroring {
  Horizontal,
  Vertical,
  SingleScreen,
  FourScreen,
  None,
}

class Cardtridge {
  Uint8List prgROM;
  Uint8List chrROM;
  Uint8List trainerROM;

  Memory sRAM; // battery-backed PRG RAM, 8kb

  bool isNES2;
  int mapperNumber;

  Mirroring mirroring;

  load(Uint8List data) {
    // parse INES header
    // see: https://wiki.nesdev.com/w/index.php/INES
    // header[0-3]: Constant $4E $45 $53 $1A ("NES" followed by MS-DOS end-of-file)
    if (!data.sublist(0, 4).equalsTo([0x4e, 0x45, 0x53, 0x1a])) {
      throw ("the first 4 bytes not equals to the nes identify");
    }

    // header[4]
    int prgNum = data.elementAt(4);

    // header[5]
    int chrNum = data.elementAt(5);

    // header[6]
    int flag6 = data.elementAt(6);

    if (flag6.getBit(3) == 1) {
      mirroring = Mirroring.FourScreen;
    } else if (flag6.getBit(0) == 0) {
      mirroring = Mirroring.Horizontal;
    } else if (flag6.getBit(0) == 1) {
      mirroring = Mirroring.Vertical;
    }

    if (flag6.getBit(1) == 1) sRAM = Memory(0x2000);

    // header[7]
    int flag7 = data.elementAt(7);
    isNES2 = (flag7 & 0x06 >> 1) == 2;

    mapperNumber = (flag7 & 0xf0) | (flag6 & 0xf0 >> 4);

    // after header
    int index = 0x10;

    if (flag6.getBit(2) == 1) {
      // update the index when using += operator
      trainerROM = data.sublist(index, index += TRAINER_SIZE);
    }

    prgROM = data.sublist(index, index += prgNum * PRG_BANK_SIZE);
    chrROM = data.sublist(index, index += chrNum * CHR_BANK_SIZE);
  }

  int readPRG(int address) => prgROM.elementAt(address);
  int readCHR(int address) => chrROM.elementAt(address);
  void writeCHR(int address, int value) => chrROM[address] = value;
}
