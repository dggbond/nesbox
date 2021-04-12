import 'dart:typed_data';

import 'package:flutter_nes/cpu.dart';
import 'package:flutter_nes/rom.dart';

// bus is used to communite between hardwares.
class NesBus {
  NesCpu cpu;
  NesRom rom;

  // communite with cpu
  int readCpuMemory(int address) => cpu.read(address);
  void writeCpuMemory(int address, int value) {
    cpu.write(address, value);
  }

  // communite with rom
  Uint8List readRomBytes(int start, int end) => rom.readBytes(start, end);
}
