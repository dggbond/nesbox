library flutter_nes;

import "dart:typed_data";

class NesRom {
  NesRom(this._data);

  Uint8List _data;

  // program counter
  int read(int pc) {
    if (pc >= _data.length) {
      return null;
    }

    return _data[pc];
  }
}
