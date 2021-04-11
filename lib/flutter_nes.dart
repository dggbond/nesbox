library flutter_nes;

import 'dart:async';
import "dart:typed_data";

import "package:flutter_nes/cpu.dart";
import "package:flutter_nes/ppu.dart";
import "package:flutter_nes/rom.dart";
import "package:flutter_nes/bus.dart";
import "package:flutter_nes/util.dart";

class NesEmulator {
  NesEmulator() {
    this.cpu = NesCPU();
    this.bus = NesBUS(cpu: this.cpu);
    this.ppu = NesPPU(this.bus);
  }

  NesCPU cpu;
  NesPPU ppu;
  NesROM rom;
  NesBUS bus;

  // load nes rom data
  loadROM(Uint8List data) async {
    rom = NesROM(data);
  }

  Future<void> powerOn() {
    rom.powerOn();
    cpu.powerOn();
    ppu.powerOn();

    return _run();
  }

  Future<void> _run() async {
    int pc = cpu.getPC();
    int opcode = rom.readProgram(pc);

    if (opcode == null) {
      print("can't read more opcode. process exit.");
      return;
    }

    Op op = findOp(opcode);
    if (op == null) {
      throw ("${opcode.toHex()} is unknown instruction at rom address ${pc.toHex()}");
    }

    var nextBytes = _getNextBytes(op, pc);

    print("running: ${enumToString(op.instr)} ${nextBytes.toHex().padRight(11, " ")}");
    int cycles = cpu.emulate(op, nextBytes);

    await Future.delayed(Duration(microseconds: (NesCPU.FREQUENCY * cycles).round()), _run);
  }

  // get bytes next to an instruction. so that cpu not need to read rom.
  Uint8List _getNextBytes(Op op, int pc) {
    final Uint8List nextBytes = Uint8List(op.bytes - 1);

    for (int i = 1; i < op.bytes; i++) {
      nextBytes[i - 1] = rom.readProgram(pc + i);
    }

    return nextBytes;
  }
}
