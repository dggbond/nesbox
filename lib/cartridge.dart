import "dart:typed_data";

import 'ines.dart';
import 'util/util.dart';

export 'ines.dart';

const int PRG_BANK_SIZE = 0x4000;
const int CHR_BANK_SIZE = 0x2000;
const int TRAINER_SIZE = 0x0200;

class Cardtridge {
  Uint8List prgROM;
  Uint8List chrROM;
  Uint8List trainerROM;

  Uint8List sRAM; // battery-backed PRG RAM, 8kb

  INesHeader header;
  Mirroring get mirroring => header.mirroring;

  loadNesFile(Uint8List gameBytes) {
    header = INesHeader(gameBytes);

    if (header.battery) sRAM = Uint8List(0x2000);

    if (header.trainer) trainerROM = gameBytes.sublistBySize(0x10, TRAINER_SIZE);

    int prgStart = header.trainer ? 0x10 + TRAINER_SIZE : 0x10;
    prgROM = gameBytes.sublistBySize(prgStart, header.prgBanks * PRG_BANK_SIZE);

    int chrStart = prgStart + header.prgBanks * PRG_BANK_SIZE;
    chrROM = gameBytes.sublistBySize(chrStart, header.chrBanks * CHR_BANK_SIZE);

    if (header.prgBanks == 0) {
      prgROM = Uint8List(PRG_BANK_SIZE);
    }
  }

  int readPRG(int address) {
    if (header.prgBanks == 1) {
      return prgROM[address - 0x4000];
    }
    return prgROM[address];
  }

  int readCHR(int address) => chrROM[address];
  void writeCHR(int address, int value) => chrROM[address] = value;
}
