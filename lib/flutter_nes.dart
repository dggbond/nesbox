library flutter_nes;

import 'dart:typed_data';

import 'package:logger/logger.dart';

import 'package:flutter_nes/cpu/cpu.dart' show NesCpu;
import 'package:flutter_nes/cpu/cpu_enum.dart';
import 'package:flutter_nes/rom.dart' show NesRom;
import 'package:flutter_nes/mapper.dart' show NesMapper;

class NesEmulator {
  NesEmulator({
    bool debugMode = false,
  }) {
    if (debugMode) {
      this._logger = Logger(
        printer: PrettyPrinter(
          lineLength: 120,
          colors: true,
          printEmojis: true,
          printTime: true,
        ),
      );
    }

    this.cpu = NesCpu(logger: this._logger);
  }

  NesCpu cpu;
  NesRom rom;

  Logger _logger;

  // load nes rom data
  loadRom(Uint8List data) async {
    rom = NesRom(data);
  }

  // start run the nes program
  run() {
    if (_logger != null) _logger.i('start run');

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
        throw ('rom address 0x${pc.toRadixString(16)} is unknown instruction.');
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
