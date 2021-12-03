import 'dart:typed_data';

export 'logger.dart';

extension IntExtension on int {
  String toHex([String prefix = '', int len = 2]) {
    return prefix + this.toUnsigned(16).toRadixString(16).padLeft(len, "0").toUpperCase();
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

  int getNegativeBit() {
    return this.getBit(7);
  }

  int getZeroBit() {
    return this == 0 ? 1 : 0;
  }

  bool inRange(int start, int end) {
    return this >= start && this <= end;
  }
}

extension Uint8ListExtension on Uint8List {
  sublistBySize(int start, int size) => this.sublist(start, start + size);
  fill(int val) => this.fillRange(0, this.length - 1, val);
}

extension FunctionExtension on Function {
  name() {
    RegExp regExp = RegExp(r"Function \'(\w+)\'");
    RegExpMatch match = regExp.firstMatch(this.toString());

    return match.group(1);
  }
}

// Map<String, String> disassemble(Uint8List bytes, [int start, int end]) {
//   Map<String, String> codeMap = Map<String, String>();

//   start ??= 0;
//   end ??= bytes.length - 1;

//   for (int index = start; index < end; index) {
//     Op op = CPU_OPS[bytes[index]];
//     String addr = index.toHex();
//     String value = op.instr.toString().split('.').last;

//     index++;
//   }
// }
