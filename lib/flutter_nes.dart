library flutter_nes;

import 'dart:typed_data';

import 'package:flutter_nes/cpu.dart' show NesCpu;
import 'package:flutter_nes/cpu_enum.dart';
import 'package:flutter_nes/rom.dart' show NesRom;
import 'package:flutter_nes/mapper.dart' show NesMapper;

class NesEmulator {
  NesCpu _cpu = NesCpu();
  NesRom _rom;
  Uint8List _rawRomData;

  // load nes rom data
  loadRom(Uint8List data) async {
    _rom = NesRom(data);
    _rawRomData = data;
  }

  // start run the nes program
  run() {
    int pc = _cpu.getPC();

    Op op = opMap[_rom.read(pc)];

    if (op == null) {
      throw ('rom address 0x${pc.toRadixString(16)} is unknown instruction.');
    }

    _cpu.emulate(op, _getNextBytes(op, pc));
  }

  // get bytes next to a instruction. so that cpu not need to read rom.
  _getNextBytes(Op op, int pc) {
    final Int8List nextBytes = Int8List(op.bytes);

    for (int i = 1; i < op.bytes; i++) {
      nextBytes[i] = _rom.read(pc + i);
    }

    return nextBytes;
  }
}
