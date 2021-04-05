import "package:flutter_test/flutter_test.dart";
import "package:flutter_nes/cpu/cpu_utils.dart" show Int8Util;

void main() {
  test("function isSameSign", () {
    assert(Int8Util.isSameSign(0x00, 0x00));
    assert(!Int8Util.isSameSign(0x80, 0x00));
    assert(Int8Util.isSameSign(0x7f, 0x01));
    assert(!Int8Util.isSameSign(0x8f, 0x01));
  });

  test("function setBitValue", () {
    int num = int.parse("11111111", radix: 2);

    assert(Int8Util.setBitValue(num, 0, 0) == int.parse("11111110", radix: 2));
    assert(Int8Util.setBitValue(num, 1, 0) == int.parse("11111101", radix: 2));
    assert(Int8Util.setBitValue(num, 2, 0) == int.parse("11111011", radix: 2));
    assert(Int8Util.setBitValue(num, 3, 0) == int.parse("11110111", radix: 2));
    assert(Int8Util.setBitValue(num, 4, 0) == int.parse("11101111", radix: 2));
    assert(Int8Util.setBitValue(num, 5, 0) == int.parse("11011111", radix: 2));
    assert(Int8Util.setBitValue(num, 6, 0) == int.parse("10111111", radix: 2));
    assert(Int8Util.setBitValue(num, 7, 0) == int.parse("01111111", radix: 2));
  });

  test("function getBitValue", () {
    int num = int.parse("10010011", radix: 2);

    assert(Int8Util.getBitValue(num, 0) == 1);
    assert(Int8Util.getBitValue(num, 1) == 1);
    assert(Int8Util.getBitValue(num, 2) == 0);
    assert(Int8Util.getBitValue(num, 3) == 0);
    assert(Int8Util.getBitValue(num, 4) == 1);
    assert(Int8Util.getBitValue(num, 5) == 0);
    assert(Int8Util.getBitValue(num, 6) == 0);
    assert(Int8Util.getBitValue(num, 7) == 1);
  });
}
