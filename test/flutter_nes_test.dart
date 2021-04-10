import "package:flutter_test/flutter_test.dart";
import "package:flutter_nes/flutter_nes.dart";
import "package:path/path.dart" as path;

import "dart:io" show Platform, File;

void main() {
  test("nes emulator load nes file", () async {
    final emulator = new NesEmulator();
    String filepath = path.join(path.dirname(Platform.script.path), "test/Megaman.nes");

    emulator.loadROM(File(filepath).readAsBytesSync());
    emulator.run();
  });
}
