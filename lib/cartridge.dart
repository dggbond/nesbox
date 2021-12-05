import "dart:typed_data";

import 'mapper.dart';
import 'util/util.dart';

const int PRG_BANK_SIZE = 0x4000;
const int CHR_BANK_SIZE = 0x2000;
const int TRAINER_SIZE = 0x0200;

enum Mirroring {
  Horizontal,
  Vertical,
  SingleScreen,
  FourScreen,
}

class Cardtridge {
  Uint8List rom; // whole game rom

  Uint8List prgROM;
  Uint8List chrROM;
  Uint8List trainerROM;
  Uint8List sRAM; // battery-backed PRG RAM, 8kb

  int prgBanks;
  int chrBanks;
  bool battery;

  Mapper mapper;
  Mirroring mirroring;

  loadNesFile(Uint8List gameBytes) {
    rom = gameBytes;

    parseNesFile(this);
  }

  int read(int address) => mapper.read(address);

  void write(int address, int value) => mapper.write(address, value);
}

parseNesFile(Cardtridge card) {
  if (card.rom == null) {
    throw "no game rom round in cardtridge";
  }

  // header[0-3]: Constant $4E $45 $53 $1A ("NES" followed by MS-DOS end-of-file)
  if (card.rom.sublist(0, 4).join() != [0x4e, 0x45, 0x53, 0x1a].join()) {
    throw ("invalid nes file");
  }

  // mirroring type
  card.mirroring = {
    0: Mirroring.Horizontal,
    1: Mirroring.Vertical,
    2: Mirroring.FourScreen,
    3: Mirroring.FourScreen,
  }[card.rom[6].getBit(3) << 1 | card.rom[6].getBit(0)];

  // battery-backed RAM Save-RAM
  card.battery = card.rom[6].getBit(1) == 1;
  card.sRAM = Uint8List(0x2000);

  int offset = 0x10; // start after header
  // trainer
  if (card.rom[6].getBit(2) == 1) {
    card.trainerROM = card.rom.sublist(0x10, offset += TRAINER_SIZE);
  }

  // program rom
  card.prgBanks = card.rom[4];
  card.prgROM = card.rom.sublist(offset, offset += card.prgBanks * PRG_BANK_SIZE);

  // character rom
  card.chrBanks = card.rom[5];
  card.chrROM = card.rom.sublist(offset, offset += card.chrBanks * CHR_BANK_SIZE);

  // sometimes rom file do not provide chr rom, instead providing in runtime
  if (card.chrBanks == 0) {
    card.chrROM = Uint8List(CHR_BANK_SIZE);
  }

  // mapper
  int lowerMapper = card.rom[6] & 0xf0;
  int upperMapper = card.rom[7] & 0xf0;

  createMapper(card, upperMapper | lowerMapper >> 4);
}
