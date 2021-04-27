import "package:flutter_nes/flutter_nes.dart";
import "package:test/test.dart";

import "dart:io" show File, Platform;


void main() {
  test("nes emulator load nes file", () async {
    final emulator = new NesEmulator();

    emulator.loadGame(File("roms/Super_mario_brothers.nes").readAsBytesSync());
    emulator.powerOn();

    if (Platform.environment.containsKey("CI")) {
      // if there is no error occurs in 20 seconds, we just think there is no problem in emulator.
      await Future.delayed(Duration(seconds: 20));
    } else {
      emulator.slowDownCpu(100000);
      await Future.delayed(Duration(days: 1));
    }
  });
}
