import "dart:io" show Platform;

extension IntUtil on int {
  String toHex([int len = 4]) {
    return "\$" + this.toUnsigned(16).toRadixString(16).padLeft(len, "0");
  }

  int getBit(int n) {
    return (this >> n) & 1;
  }

  int setBit(int n, int value) {
    int num = this;
    if (value == 1) {
      num |= 1 << n;
    } else if (value == 0) {
      num &= ~(1 << n);
    } else {
      throw ("value must be 0 or 1");
    }

    return num;
  }

  int getNegativeBit() {
    return this.getBit(7);
  }

  int getZeroBit() {
    return this == 0 ? 1 : 0;
  }
}

extension IntListUtil on List<int> {
  String toHex([len = 4]) {
    return this.map((e) => e.toHex(len)).join(",");
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

void debugLog(String message) {
  if (Platform.environment.containsKey("NES_DEBUG")) {
    print(message);
  }
}
