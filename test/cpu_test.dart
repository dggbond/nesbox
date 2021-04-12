import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:flutter_nes/cpu.dart";

void main() {
  test("cpu test", () {
    final cpu = NesCpu();

    cpu.powerOn();
    cpu.emulate(findOp(0xa9), [0x10]); // LDA, 0x10

    assert(cpu.getACC() == 0x10);
  });
}
