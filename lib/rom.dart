library flutter_nes;

import "dart:typed_data";

class NesROM {
  NesROM(this._data);

  Uint8List _data;

  // program counter
  int read(int pc) {
    if (pc >= _data.length) {
      return null;
    }

    return _data[pc];
  }
}
