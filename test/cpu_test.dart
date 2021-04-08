import "dart:typed_data";

import "package:flutter_test/flutter_test.dart";
import "package:flutter_nes/cpu/cpu.dart";

void main() {
  test("cpu test", () {
    final cpu = NesCPU();

    cpu.emulate(findOp(0xa9), Uint8List.fromList([0x10])); // LDA, 0x10

    assert(cpu.getACC() == 0x10);
  });
}
