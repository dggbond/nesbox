library flutter_nes;

import "dart:typed_data";

class NesCPUMemory {
  NesCPUMemory();

  static const int SIZE = 0x10000;

  // RAM RANGES
  static const List<int> ZERO_PAGE_RANGE = [0x0000, 0x0100];
  static const List<int> STACK_RANGE = [0x0100, 0x0200];
  static const List<int> RAM_RANGE = [0x0200, 0x0800];
  static const List<int> RAM_MIRRORS_RANGE = [0x0800, 0x2000]; // mirroring $0000-$07ff

  // I/O Registers RANGES
  static const List<int> IO_REGS_1_RANGE = [0x2000, 0x2008];
  static const List<int> IO_REGS_1_MIRRORS_RANGE = [0x2008, 0x4000]; // mirroring $2000-$2007
  static const List<int> IO_REGS_2_RANGE = [0x4000, 0x4020];

  // Expansion ROM RANGES
  static const List<int> EXPANSION_ROM_RANGE = [0x4020, 0x6000];

  // SRAM RANGES
  static const List<int> SRAM_RANGE = [0x6000, 0x8000];

  // PRG-ROM RANGES
  static const List<int> LOWER_PRG_ROM_RANGE = [0x8000, 0xc000];
  static const List<int> UPPER_PRG_ROM_RANGE = [0xc000, 0x10000];

  final Int8List _mem = Int8List(SIZE); // 64kb memory;

  int read(int address) {
    if (address >= SIZE) {
      throw ("addressing 0x${address.toRadixString(16).padLeft(4, "0")} failed. this address is overflow memory size.");
    }

    return _mem.elementAt(address);
  }

  void write(int address, int value) {
    if (value >= SIZE) {
      throw ("writing memory failed. this address is overflow memory size.");
    }

    if (_in(address, RAM_MIRRORS_RANGE)) {
      throw ("write memory failed. trying to write the RAM mirroring memeory.");
    }

    if (_in(address, IO_REGS_1_MIRRORS_RANGE)) {
      throw ("write memory failed. trying to write the I/O Registers mirroring memeory.");
    }

    if (_in(address, ZERO_PAGE_RANGE) || _in(address, STACK_RANGE) || _in(address, RAM_RANGE)) {
      _mem[address] = value;
      while (_in(address += 0x0800, RAM_MIRRORS_RANGE)) {
        _mem[address] = value;
      }
    }

    if (_in(address, IO_REGS_1_RANGE)) {
      _mem[address] = value;
      while (_in(address += 0x0008, IO_REGS_1_MIRRORS_RANGE)) {
        _mem[address] = value;
      }
    }

    if (_in(address, IO_REGS_2_RANGE) ||
        _in(address, EXPANSION_ROM_RANGE) ||
        _in(address, SRAM_RANGE) ||
        _in(address, LOWER_PRG_ROM_RANGE) ||
        _in(address, UPPER_PRG_ROM_RANGE)) {
      _mem[address] = value;
    }
  }

  // detect an address is in a range or not;
  bool _in(int address, List<int> range) {
    return address >= range[0] && address < range[1];
  }
}

class NesPPUMemory {
  static const int SIZE = 0x10000;

  // Pattern Tables RANGES
  static const List<int> PATTERN_TABLE_0_RANGE = [0x0000, 0x1000];
  static const List<int> PATTERN_TABLE_1_RANGE = [0x1000, 0x2000];

  // Name Tables RANGES
  static const List<int> NAME_TABLE_0_RANGE = [0x2000, 0x23c0];
  static const List<int> ATTRIBUTE_TABLE_0_RANGE = [0x23c0, 0x2400];
  static const List<int> NAME_TABLE_1_RANGE = [0x2400, 0x27c0];
  static const List<int> ATTRIBUTE_TABLE_1_RANGE = [0x27c0, 0x2800];
  static const List<int> NAME_TABLE_2_RANGE = [0x2800, 0x2bc0];
  static const List<int> ATTRIBUTE_TABLE_2_RANGE = [0x2bc0, 0x2c00];
  static const List<int> NAME_TABLE_3_RANGE = [0x2c00, 0x2fc0];
  static const List<int> ATTRIBUTE_TABLE_3_RANGE = [0x2fc0, 0x3000];

  static const List<int> NAME_TABLES_MIRRORS_RANGE = [0x3000, 0x3f00]; // mirroring $2000-$2eff

  // Palettes RANGES
  static const List<int> IMAGE_PALETTES_RANGE = [0x3f00, 0x3f10];
  static const List<int> SPRITE_PALETTES_RANGE = [0x3f10, 0x3f20];
  static const List<int> PALETTES_MIRRORS_RANGE = [0x3f20, 0x4000]; // mirroring $3f00-$3f1f

  static const List<int> MIRRORS_RANGE = [0x4000, 0x10000]; // mirroring $0000-$3fff

  final Int8List _mem = Int8List(SIZE); // 64kb memory;

  int read(int address) {
    return _mem[address];
  }

  void write(int address, int value) {
    _mem[address] = value & 0xff;
  }
}
