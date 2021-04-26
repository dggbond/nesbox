import "package:flutter_nes/util.dart";
import "package:test/test.dart";

void main() {
  test("setBit", () {
    int num = int.parse("11111111", radix: 2);

    assert(num.setBit(0, 0) == int.parse("11111110", radix: 2));
    assert(num.setBit(1, 0) == int.parse("11111101", radix: 2));
    assert(num.setBit(2, 0) == int.parse("11111011", radix: 2));
    assert(num.setBit(3, 0) == int.parse("11110111", radix: 2));
    assert(num.setBit(4, 0) == int.parse("11101111", radix: 2));
    assert(num.setBit(5, 0) == int.parse("11011111", radix: 2));
    assert(num.setBit(6, 0) == int.parse("10111111", radix: 2));
    assert(num.setBit(7, 0) == int.parse("01111111", radix: 2));
  });

  test("getBit", () {
    int num = int.parse("10010011", radix: 2);

    assert(num.getBit(0) == 1);
    assert(num.getBit(1) == 1);
    assert(num.getBit(2) == 0);
    assert(num.getBit(3) == 0);
    assert(num.getBit(4) == 1);
    assert(num.getBit(5) == 0);
    assert(num.getBit(6) == 0);
    assert(num.getBit(7) == 1);
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
