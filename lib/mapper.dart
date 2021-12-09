library flutter_nes.mapper;

import 'cartridge.dart';

abstract class Mapper {
  Mapper(this.card);

  Cardtridge card;

  int read(int address) {}

  void write(int address, int value) {}
}

// NORM: https://wiki.nesdev.org/w/index.php?title=NROM
class Mapper0 extends Mapper {
  Mapper0(Cardtridge card) : super(card);

  @override
  read(int address) {
    if (address < 0x2000) {
      return card.chrROM[address];
    }

    if (address >= 0x6000 && address < 0x8000) {
      if (card.battery) return card.sRAM[address - 0x6000];
      return 0;
    }

    if (address >= 0x8000) {
      int offset = address - 0x8000;
      return card.prgROM[card.prgBanks == 1 ? offset % 0x4000 : offset];
    }

    return 0;
  }

  @override
  write(int address, int value) {
    if (address < 0x2000) {
      card.chrROM[address] = value;
    }

    if (address >= 0x6000 && address < 0x8000) {
      if (card.battery) card.sRAM[address - 0x6000] = value;
    }
    return;
  }
}

createMapper(Cardtridge card, int mapperID) {
  switch (mapperID) {
    case 0:
      card.mapper = Mapper0(card);
  }
}
