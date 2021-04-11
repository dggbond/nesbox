import 'package:flutter_nes/cpu.dart';

class NesBUS {
  NesBUS({NesCPU cpu}) : this._cpu = cpu;

  final NesCPU _cpu;

  void writeCpuMemory(int address, int value) {
    _cpu.write(address, value);
  }

  int readCpuMemory(int address) => _cpu.read(address);
}
