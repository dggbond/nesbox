class Int8 {
  Int8([int _num = 0]) {
    if (_num < 0) {
      this._num = 0x80 + _num.abs();
    } else {
      this._num = _num;
    }
  }

  int _num;

  Int8 operator <<(int leftShiftLen) {
    _num <<= leftShiftLen;
    return this;
  }

  Int8 operator >>(int rightShiftLen) {
    _num >>= rightShiftLen;
    return this;
  }

  Int8 operator &(Int8 target) {
    return Int8(_num & target.toInt());
  }

  Int8 operator |(Int8 target) {
    return Int8(_num | target.toInt());
  }

  Int8 operator ^(Int8 target) {
    return Int8(_num ^ target.toInt());
  }

  Int8 operator +(Int8 target) {
    return Int8(_num + target.toInt());
  }

  Int8 operator -(Int8 target) {
    return Int8(_num - target.toInt());
  }

  bool operator >=(Int8 target) {
    return _num >= target.toInt();
  }

  bool operator >(Int8 target) {
    return _num > target.toInt();
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
      throw ("value must be 0 or 1");
    }

    return Int8(_num);
  }

  int isNegative() {
    return _num >> 7 & 1;
  }

  int isZero() {
    return _num == 0 ? 1 : 0;
  }

  int isOverflow() {
    return _num >> 8 == 0 ? 0 : 1;
  }

  int toInt() {
    return _num & 0xff;
  }

  int get sign {
    return (_num >> 7) & 1;
  }

  String toHex([int len = 4]) {
    return "\$" + _num.toUnsigned(16).toRadixString(16).padLeft(len, "0");
  }
}
