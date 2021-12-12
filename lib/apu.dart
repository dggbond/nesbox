library nesbox.apu;

import 'bus.dart';

// TODO: apu implements.
class APU {
  BUS bus;

  int readRegister(int address) {
    if (address == 0x4004) return 0xff;
    if (address == 0x4005) return 0xff;
    if (address == 0x4006) return 0xff;
    if (address == 0x4007) return 0xff;
    if (address == 0x4015) return 0xff;

    return 0;
  }

  void writeRegister(int address, int value) {}
}
