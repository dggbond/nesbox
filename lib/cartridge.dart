library nesbox.cartridge;

import "dart:typed_data";

import 'package:nesbox/frame.dart';
import 'package:nesbox/palette.dart';

import 'mapper.dart';
import 'util/int_extension.dart';

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
  late Uint8List rom; // whole game rom

  late Uint8List prgROM;
  late Uint8List chrROM;
  late Uint8List trainerROM;
  late Uint8List sRAM; // battery-backed PRG RAM, 8kb

  late int prgBanks;
  late int chrBanks;
  late bool battery;

  late Mapper mapper;
  late Mirroring mirroring;

  TileFrame firstTileFrame = TileFrame();
  TileFrame secondTileFrame = TileFrame();

  loadNesFile(Uint8List gameBytes) {
    rom = gameBytes;

    parse();
    createTileFrame(firstTileFrame);
    createTileFrame(secondTileFrame, 0x1000);
  }

  int read(int address) => mapper.read(address);

  void write(int address, int value) => mapper.write(address, value);

  parse() {
    if (this.rom == null) {
      throw "no game rom round in cardtridge";
    }

    // header[0-3]: Constant $4E $45 $53 $1A ("NES" followed by MS-DOS end-of-file)
    if (this.rom.sublist(0, 4).join() != [0x4e, 0x45, 0x53, 0x1a].join()) {
      throw ("invalid nes file");
    }

    // mirroring type
    this.mirroring = {
      0: Mirroring.Horizontal,
      1: Mirroring.Vertical,
      2: Mirroring.FourScreen,
      3: Mirroring.FourScreen,
    }[this.rom[6].getBit(3) << 1 | this.rom[6].getBit(0)]!;

    // battery-backed RAM Save-RAM
    this.battery = this.rom[6].getBit(1) == 1;
    this.sRAM = Uint8List(0x2000);

    int offset = 0x10; // start after header
    // trainer
    if (this.rom[6].getBit(2) == 1) {
      this.trainerROM = this.rom.sublist(0x10, offset += TRAINER_SIZE);
    }

    // program rom
    this.prgBanks = this.rom[4];
    this.prgROM = this.rom.sublist(offset, offset += this.prgBanks * PRG_BANK_SIZE);

    // character rom
    this.chrBanks = this.rom[5];
    this.chrROM = this.rom.sublist(offset, offset += this.chrBanks * CHR_BANK_SIZE);

    // sometimes rom file do not provide chr rom, instead providing in runtime
    if (this.chrBanks == 0) {
      this.chrROM = Uint8List(CHR_BANK_SIZE);
    }

    // mapper
    int lowerMapper = this.rom[6] & 0xf0;
    int upperMapper = this.rom[7] & 0xf0;

    Mapper.create(this, upperMapper | lowerMapper >> 4);
  }

  createTileFrame(TileFrame frame, [int baseAddress = 0]) {
    for (int tiles = 0; tiles < 0x100; tiles++) {
      for (int fineY = 0; fineY < 8; fineY++) {
        var lowTile = read(baseAddress + tiles * 8 + fineY);
        var highTile = read(baseAddress + tiles * 8 + fineY + 8);

        for (int fineX = 0; fineX < 8; fineX++) {
          int lowBit = lowTile.getBit(7 - fineX);
          int highBit = highTile.getBit(7 - fineX);

          int x = (tiles % 16) * 8 + fineX;
          int y = (tiles / 16).floor() * 8 + fineY;

          frame.setPixel(x, y, NES_SYS_PALETTES[highBit << 1 | lowBit] ?? 0);
        }
      }
    }
  }
}
