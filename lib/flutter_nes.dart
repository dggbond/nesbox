library flutter_nes;

import "dart:typed_data";

import "package:flutter_nes/cpu/cpu.dart" show NesCpu;
import "package:flutter_nes/cpu/cpu_enum.dart";
import "package:flutter_nes/rom.dart" show NesRom;
import "package:flutter_nes/util.dart";
import "package:flutter_nes/mapper.dart" show NesMapper;
import "package:flutter_nes/logger.dart" show NesLogger;

class NesEmulator {
  NesEmulator({
    bool debugMode = false,
  }) {
    this._logger = NesLogger(debugMode);
    this.cpu = NesCpu(logger: this._logger);
  }

  NesCpu cpu;
  NesRom rom;

  NesLogger _logger;

  // load nes rom data
  loadRom(Uint8List data) async {
    rom = NesRom(data);
  }

  // start run the nes program
  run() {
    _logger.i("start running the nes program.");

    cpu.logRegisterStatus();
    while (true) {
      int pc = cpu.getPC();
      int opcode = rom.read(pc);

      if (opcode == null) {
        _logger.w("can't read more opcode. process exit.");
        return;
      }

      Op op = findOp(opcode);
      if (op == null) {
        throw ("${toHex(opcode)} is unknown instruction at rom address 0x${toHex(pc)}");
      }

      cpu.emulate(op, _getNextBytes(op, pc));
      cpu.logRegisterStatus();
    }
  }

  // get bytes next to a instruction. so that cpu not need to read rom.
  _getNextBytes(Op op, int pc) {
    final Int8List nextBytes = Int8List(op.bytes - 1);

    for (int i = 1; i < op.bytes; i++) {
      nextBytes[i - 1] = rom.read(pc + i);
    }

    return nextBytes;
  }
}
