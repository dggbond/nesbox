import "dart:io";

extension IntUtil on int {
  String toHex([int len = 4]) {
    return "\$" + this.toUnsigned(16).toRadixString(16).padLeft(len, "0");
  }

  int getBit(int n) {
    return (this >> n) & 0x01;
  }

  int getBits(int start, int end) {
    int bits = 0;

    for (int n = 0; n < end - start + 1; n++) {
      bits <<= 1;
      bits |= this.getBit(end - n);
    }
    return bits;
  }
}

extension IntListUtil on List<int> {
  String toHex() {
    return this.map((e) => e.toHex()).join(",");
  }

  bool equalsTo(List<int> targetList) {
    // equals length first.
    if (targetList.length != this.length) return false;

    for (int i = 0; i < this.length; i++) {
      if (this.elementAt(i) != targetList.elementAt(i)) {
        return false;
      }
    }

    return true;
  }
}
// one page is 8-bit size;
bool isPageCrossed(int addr1, int addr2) {
  return addr1 & 0xff00 != addr2 & 0xff00;
}

// bytes can be Uint8List | List<int>
int to16Bit(dynamic bytes) {
  return (bytes[1] << 8) | bytes[0] & 0xffff;
}

void debugLog(String message) {
  if (Platform.environment.containsKey("NES_DEBUG")) {
    print(message);
  }
}
