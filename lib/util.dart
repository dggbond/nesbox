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

class Int8 {
  Int8([this._num = 0]);

  // check an int is 8-bit or not;
  static isValid(int target) {
    return target >> 8 == 0;
  }

  int _num = 0;

  Int8 operator <<(int leftShiftLen) {
    _num <<= leftShiftLen;
    return this;
  }

  Int8 operator >>(int rightShiftLen) {
    _num >>= rightShiftLen;
    return this;
  }

  Int8 operator &(Int8 target) {
    return Int8(val & target.val);
  }

  Int8 operator |(Int8 target) {
    return Int8(val | target.val);
  }

  Int8 operator ^(Int8 target) {
    return Int8(val ^ target.val);
  }

  Int8 operator +(Int8 target) {
    return Int8(val + target.val);
  }

  Int8 operator -(Int8 target) {
    return Int8(val - target.val);
  }

  bool operator >=(Int8 target) {
    return val >= target.val;
  }

  bool operator >(Int8 target) {
    return val > target.val;
  }

  int getBit(int n) {
    return (_num >> n) & 1;
  }

  int getBits(int start, int end) {
    int bits = 0;

    for (int n = 0; n < end - start + 1; n++) {
      bits <<= 1;
      bits |= this.getBit(end - n);
    }
    return bits;
  }

  Int8 setBit(int n, int value) {
    if (value == 1) {
      _num |= 1 << n;
    } else if (value == 0) {
      _num &= ~(1 << n);
    } else {
      throw (".value must be 0 or 1");
    }

    return Int8(_num);
  }

  int isPositive() {
    return _num >> 7 ^ 1;
  }

  int isNegative() {
    return _num >> 7 & 1;
  }

  int isZero() {
    return val == 0 ? 1 : 0;
  }

  int isOverflow() {
    return _num >> 8 == 0 ? 0 : 1;
  }

  int get val {
    return _num & 0xff;
  }

  int get sign {
    return _num >> 7 & 1;
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
