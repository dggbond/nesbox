library flutter_nes;

import 'dart:typed_data';

import 'package:flutter_nes/cpu.dart' show NesCpu;
import 'package:flutter_nes/cpu_enum.dart';
import 'package:flutter_nes/rom.dart' show NesRom;
import 'package:flutter_nes/mapper.dart' show NesMapper;

class NesEmulator {
  NesCpu cpu = NesCpu();
  NesRom rom;
  Uint8List _rawRomData;

  // load nes rom data
  loadRom(Uint8List data) async {
    rom = NesRom(data);
    _rawRomData = data;
  }

  // start run the nes program
  run() {
    while (true) {
      int pc = cpu.getPC();
      int opcode = rom.read(pc);

      if (opcode == null) {
        // game program is all readed. return.
        print("can't read opcode from program. process exit.");
        return;
      }

      Op op = opMap[opcode];
      if (op == null) {
        throw ('rom address 0x${pc.toRadixString(16)} is unknown instruction.');
      }

      print('cpu is emualting instruction: ${op.ins}');
      cpu.emulate(op, _getNextBytes(op, pc));
    }
  }

  // get bytes next to a instruction. so that cpu not need to read rom.
  _getNextBytes(Op op, int pc) {
    final Int8List nextBytes = Int8List(op.bytes);

    for (int i = 1; i < op.bytes; i++) {
      nextBytes[i] = rom.read(pc + i);
    }

    return nextBytes;
  }
}
