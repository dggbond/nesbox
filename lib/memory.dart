library flutter_nes;

import 'dart:typed_data';

class NesCpuMemory {
  NesCpuMemory();

  static const int SIZE = 0x10000;
  static const int RAM_SIZE = 0x2000;
  static const int RAM_CHUNK_SIZE = 0x0800;
  static const int IO_RESIGERS_SIZE = 0x2020;
  static const int IO_RESIGERS_CHUNK_SIZE = 0x0008;
  static const int EXPANSION_ROM_SIZE = 0x1fe0;
  static const int SRAM_SIZE = 0x2000;
  static const int RPG_ROM_SIZE = 0x8000;
  static const int RPG_ROM_UPPER_BANK_SIZE = 0x4000;
  static const int RPG_ROM_LOWER_BANK_SIZE = 0x4000;

  final Int8List _mem = Int8List(SIZE); // 64kb memory;

  int read(int address) {
    int level = RAM_SIZE;
    if (address < level) {
      // 0x00 - 0xff is zero page
      if (address % RAM_CHUNK_SIZE < 0xff) {
        return _mem[address];
      }

      // 0x0100 - 0x0200 is Stack
      if (address % RAM_CHUNK_SIZE < 0x0200) {
        return _mem[address];
      }

      // 0x0200 - 0x0800 is RAM
      if (address % RAM_CHUNK_SIZE < 0x800) {
        return _mem[address];
      }
    }

    level += IO_RESIGERS_SIZE;
    if (address < level) {
      return _mem[address];
    }

    level += EXPANSION_ROM_SIZE;
    if (address < level) {
      return _mem[address];
    }

    level += SRAM_SIZE;
    if (address < level) {
      return _mem[address];
    }

    level += RPG_ROM_SIZE;
    if (address < level) {
      int index = address - level;

      if (address < RPG_ROM_LOWER_BANK_SIZE) {
        return _mem[address];
      }

      // left is upper bank
      return _mem[address];
    }

    throw ("addressing 0x${address.toRadixString(16)} failed. this address is overflow memory size.");
  }

  void write(int address, int value) {
    if (value >= SIZE) {
      throw ("addressing 0x${address.toRadixString(16)} failed. this address is overflow memory size.");
    }

    _mem[address] = value;
  }
}
