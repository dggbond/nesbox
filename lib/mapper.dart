import 'cartridge.dart';
import 'util/util.dart';

abstract class Mapper {
  Mapper(this.card);

  int prgBank1;
  int prgBank2;

  Cardtridge card;

  int read(int address) {}

  void write(int address, int value) {}
}

class Mapper0 extends Mapper {
  Mapper0(Cardtridge card) : super(card) {
    prgBank1 = 0;
    prgBank2 = card.prgBanks - 1;
  }

  @override
  read(int address) {
    if (address < 0x2000) {
      return card.chrROM[address];
    } else if (address >= 0x6000 && address < 0x8000) {
      return card.sRAM[address - 0x6000];
    } else if (address >= 0x8000 && address < 0xc000) {
      return card.prgROM[address - 0x8000];
    } else if (address >= 0xc000) {
      return card.prgROM[prgBank2 * PRG_BANK_SIZE + address - 0xc000];
    } else {
      throw "unhandled mapper address: ${address.toHex()}";
    }
  }

  @override
  write(int address, int value) {
    if (address < 0x2000) {
      card.chrROM[address] = value;
    } else if (address >= 0x6000 && address < 0x8000) {
      card.sRAM[address - 0x6000] = value;
    } else {
      throw "unhandled mapper address: ${address.toHex()}";
    }
  }
}

createMapper(Cardtridge card, int mapperID) {
  switch (mapperID) {
    case 0:
      card.mapper = Mapper0(card);
  }
}
