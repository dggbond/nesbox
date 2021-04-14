import "dart:typed_data";

import 'package:flutter_nes/util.dart';

class RAM {
  RAM(int size) : _mem = Uint8List(size);

  final Uint8List _mem;

  int read(int address) {
    return _mem.elementAt(address);
  }

  void write(int address, int value) {
    _mem[address] = value;
  }

  int read16Bit(int address) {
    return to16Bit([read(address + 1), read(address)]);
  }

  Uint8List readBytes(int start, int count) {
    if (count == 0) return Uint8List(0);
    return _mem.sublist(start, start + count);
  }

  void writeBytes(List<int> range, Uint8List data) {
    _mem.setRange(range[0], range[1], data);
  }
}
