import "package:flutter_nes/flutter_nes.dart";
import "package:path/path.dart" as path;
import "package:test/test.dart";

import "dart:io" show Platform, File;

void main() {
  test("nes emulator load nes file", () async {
    final emulator = new NesEmulator();

    emulator.loadGame(File("roms/Super_mario_brothers.nes").readAsBytesSync());
    emulator.powerOn();

    // if there is no error occurs in one minute, we just think there is no problem in emulator.
    await Future.delayed(Duration(minutes: 1));
  });
}
