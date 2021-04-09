library flutter_nes;

import "dart:typed_data";

import "package:flutter_nes/cpu/cpu.dart";
import "package:flutter_nes/rom.dart" show NesROM;
import 'package:flutter_nes/util.dart';
import "package:flutter_nes/logger.dart" show NesLogger;

class NesEmulator {
  NesEmulator() {
    this._logger = NesLogger();
    this.cpu = NesCPU();
  }

  NesCPU cpu;
  NesROM rom;

  NesLogger _logger;

  // load nes rom data
  loadROM(Uint8List data) async {
    rom = NesROM(data);
  }

  // start run the nes program
  run() {
    _logger.info("start running the nes program.");

    while (true) {
      int pc = cpu.getPC();
      int opcode = rom.readProgram(pc);

      if (opcode == null) {
        _logger.info("can't read more opcode. process exit.");
        return;
      }

      Op op = findOp(opcode);
      if (op == null) {
        throw ("${opcode.toHex()} is unknown instruction at rom address ${pc.toHex()}");
      }

      cpu.emulate(op, _getNextBytes(op, pc));
    }
  }

  // get bytes next to a instruction. so that cpu not need to read rom.
  Uint8List _getNextBytes(Op op, int pc) {
    final Uint8List nextBytes = Uint8List(op.bytes - 1);

    for (int i = 1; i < op.bytes; i++) {
      nextBytes[i - 1] = rom.readProgram(pc + i);
    }

    return nextBytes;
  }
}
