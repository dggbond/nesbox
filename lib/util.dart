import "dart:convert";

String jsonStringify(Object object) {
  var encoder = new JsonEncoder.withIndent("  ");

  return encoder.convert(object);
}

String toHex(int num) {
  return num.toRadixString(16).padLeft(2, "0");
}

String toBinary(int num) {
  return (num & 0xff).toRadixString(2).padLeft(8, "0");
}

// one page is 8-bit size;
bool isPageCrossed(int addr1, int addr2) {
  return addr1 & 0xff00 != addr2 & 0xff00;
}

class Int8Util {
  static bool isSameSign(int a, int b) {
    return Int8Util.isPositive(a) ^ Int8Util.isPositive(b) == 0;
  }

  // targetBit is right to left, eg: 00000x00, x is index 2
  static int setBitValue(int num, int targetBit, int value) {
    if (value != 0 && value != 1) {
      throw ("value param must be 0 or 1, got $value");
    }

    String bitStr = "11111111";
    int index = bitStr.length - targetBit;
    return num & int.parse(bitStr.replaceRange(index, index, "0"), radix: 2) | value;
  }

  static int getBitValue(int num, int targetBit) {
    return (num >> targetBit) & 1;
  }

  static int isPositive(int num) {
    return num >> 7 ^ 1;
  }

  static int isNegative(int num) {
    return num >> 7 & 1;
  }

  static int isZero(int num) {
    return num & 0xff == 0 ? 1 : 0;
  }

  static int isOverflow(int num) {
    return (num > 0x7f || num < -0x7f) ? 1 : 0;
  }

  static int join(int a, int b) {
    return (a << 2 + b) & 0xff;
  }
}
