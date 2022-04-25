import 'package:nesbox/util/int_extension.dart';
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
}
