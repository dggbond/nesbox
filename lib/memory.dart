library flutter_nes;

import 'dart:typed_data';

class NesCpuMemory {
  NesCpuMemory() : _mem = Int8List(0x10000); // 64kb memory;

  final Int8List _mem;

  int read(int address) {
    // 0x00 - 0xff is zero page
    if (address < 0xff) {
      return _mem[address];
    }

    return _mem[address];
  }

  void write(int address, int value) {
    _mem[address] = value;
  }
}
