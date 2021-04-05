import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_nes/flutter_nes.dart';
import 'package:path/path.dart' as path;
import 'dart:io' show Platform, File;

void main() {
//   test('nes emulator load nes file', () async {
//     final emulator = new NesEmulator();
//     String filepath = path.join(path.dirname(Platform.script.path), 'test/Megaman.nes');
//
//     emulator.loadRom(File(filepath).readAsBytesSync());
//     emulator.run();
//   });

  test('nes emulator load test program', () {
    final emulator = new NesEmulator(debugMode: true);

    emulator.loadRom(Uint8List.fromList([
      0xa9, 0x10, // LDA #$10     -> A = #$10
    ]));
    emulator.run();

    assert(emulator.cpu.getACC() == 0x10);
  });
}
