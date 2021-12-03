import 'dart:typed_data';
import 'util/util.dart';

enum Mirroring {
  Horizontal,
  Vertical,
  SingleScreen,
  FourScreen,
}

class INesHeader {
  int prgBanks;
  int chrBanks;

  int mapperID;

  Mirroring mirroring;

  bool battery;
  bool trainer;

  // load NES file and parse INES header
  // see: https://wiki.nesdev.com/w/index.php/INES
  INesHeader(Uint8List bytes) {
    // header[0-3]: Constant $4E $45 $53 $1A ("NES" followed by MS-DOS end-of-file)
    if (bytes.sublist(0, 4).join() != [0x4e, 0x45, 0x53, 0x1a].join()) {
      throw ("invalid nes file");
    }

    prgBanks = bytes[4];
    chrBanks = bytes[5];

    int lowerMapper = bytes[6] & 0xf0;
    int upperMapper = bytes[7] & 0xf0;
    mapperID = upperMapper | lowerMapper >> 4;

    mirroring = {
      0: Mirroring.Horizontal,
      1: Mirroring.Vertical,
      2: Mirroring.FourScreen,
      3: Mirroring.FourScreen,
    }[bytes[6].getBit(3) << 1 | bytes[6].getBit(0)];

    battery = bytes[6].getBit(1) == 1;
    trainer = bytes[6].getBit(2) == 1;
  }
}
