import "dart:typed_data";

class Memory {
  Memory(int size) : _mem = Uint8List(size);

  final Uint8List _mem;

  int read(int address) => _mem[address];

  write(int address, int value) => _mem[address] = value;

  clear() => _mem.fillRange(0, _mem.length, 0x00);
}
