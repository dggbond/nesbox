import "package:flutter_test/flutter_test.dart";
import "package:flutter_nes/util.dart";

void main() {
  test("function isSameSign", () {
    assert(Int8(0x00).sign == Int8(0x00).sign);
    assert(Int8(0x80).sign != Int8(0x00).sign);
    assert(Int8(0x7f).sign == Int8(0x01).sign);
    assert(Int8(0x8f).sign != Int8(0x01).sign);
  });

  test("function setBit", () {
    int num = int.parse("11111111", radix: 2);

    assert(Int8(num).setBit(0, 0).value == int.parse("11111110", radix: 2));
    assert(Int8(num).setBit(1, 0).value == int.parse("11111101", radix: 2));
    assert(Int8(num).setBit(2, 0).value == int.parse("11111011", radix: 2));
    assert(Int8(num).setBit(3, 0).value == int.parse("11110111", radix: 2));
    assert(Int8(num).setBit(4, 0).value == int.parse("11101111", radix: 2));
    assert(Int8(num).setBit(5, 0).value == int.parse("11011111", radix: 2));
    assert(Int8(num).setBit(6, 0).value == int.parse("10111111", radix: 2));
    assert(Int8(num).setBit(7, 0).value == int.parse("01111111", radix: 2));
  });

  test("function getBit", () {
    int num = int.parse("10010011", radix: 2);

    assert(Int8(num).getBit(0) == 1);
    assert(Int8(num).getBit(1) == 1);
    assert(Int8(num).getBit(2) == 0);
    assert(Int8(num).getBit(3) == 0);
    assert(Int8(num).getBit(4) == 1);
    assert(Int8(num).getBit(5) == 0);
    assert(Int8(num).getBit(6) == 0);
    assert(Int8(num).getBit(7) == 1);
  });
}
