export 'logger.dart';

extension IntExtension on int {
  String toHex([int len = 2]) {
    return this.toUnsigned(16).toRadixString(16).padLeft(len, "0").toUpperCase();
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

  int getZeroBit() {
    return (this & 0xff) == 0 ? 1 : 0;
  }
}
