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

  int getNegativeBit() {
    return this.getBit(7);
  }

  int getZeroBit() {
    return (this & 0xff) == 0 ? 1 : 0;
  }

  bool inRange(int start, int end) {
    return this >= start && this <= end;
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
