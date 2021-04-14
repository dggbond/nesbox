import "package:flutter_test/flutter_test.dart";
import "package:flutter_nes/util.dart";

void main() {
  test("Int8 sign", () {
    assert(Int8(0x00).sign == Int8(0x00).sign);
    assert(Int8(0x80).sign != Int8(0x00).sign);
    assert(Int8(0x7f).sign == Int8(0x01).sign);
    assert(Int8(0x8f).sign != Int8(0x01).sign);
  });

  test("setBit", () {
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

  test("getBit", () {
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

  test("getBits", () {
    int num = int.parse("10010011", radix: 2);

    assert(num.getBits(0, 3) == int.parse("0011", radix: 2));
    assert(num.getBits(1, 3) == int.parse("001", radix: 2));
    assert(num.getBits(2, 3) == int.parse("00", radix: 2));
    assert(num.getBits(3, 3) == int.parse("0", radix: 2));
    assert(num.getBits(4, 7) == int.parse("1001", radix: 2));
    assert(num.getBits(5, 7) == int.parse("100", radix: 2));
    assert(num.getBits(6, 7) == int.parse("10", radix: 2));
    assert(num.getBits(7, 7) == int.parse("1", radix: 2));
  });
}
