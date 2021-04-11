import "dart:convert";
import "dart:typed_data";

extension IntStringify on int {
  String toHex() {
    return "\$" + this.toRadixString(16).padLeft(4, "0");
  }

  int getBit(int n) {
    return (this >> n) & 1;
  }
}

extension Int8ListStringify on Int8List {
  String toHex() {
    return this.map((e) => e.toHex()).join(",");
  }
}

extension Uint8ListStringify on Uint8List {
  String toHex() {
    return this.map((e) => e.toHex()).join(",");
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
    return Int8(value & target.value);
  }

  Int8 operator |(Int8 target) {
    return Int8(value | target.value);
  }

  Int8 operator ^(Int8 target) {
    return Int8(value ^ target.value);
  }

  Int8 operator +(Int8 target) {
    return Int8(value + target.value);
  }

  Int8 operator -(Int8 target) {
    return Int8(value - target.value);
  }

  bool operator >=(Int8 target) {
    return value >= target.value;
  }

  bool operator >(Int8 target) {
    return value > target.value;
  }

  int getBit(int n) {
    return (_num >> n) & 1;
  }

  Int8 setBit(int n, int value) {
    if (value == 1) {
      _num |= 1 << n;
    } else if (value == 0) {
      _num &= ~(1 << n);
    } else {
      throw ("value must be 0 or 1");
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
    return value == 0 ? 1 : 0;
  }

  int isOverflow() {
    return _num >> 8 == 0 ? 0 : 1;
  }

  int join(int a, int b) {
    return (a << 2 + b) & 0xff;
  }

  int get value {
    return _num & 0xff;
  }

  int get sign {
    return _num >> 7 & 1;
  }
}

String jsonStringify(Object object) {
  var encoder = new JsonEncoder.withIndent("  ");

  return encoder.convert(object);
}

// one page is 8-bit size;
bool isPageCrossed(int addr1, int addr2) {
  return addr1 & 0xff00 != addr2 & 0xff00;
}

// bytes can be Uint8List | List<int>
int to16Bit(dynamic bytes) {
  return (bytes[1] << 2) | bytes[0] & 0xffff;
}

String enumToString(dynamic value) {
  return value.toString().split(".")[1];
}
