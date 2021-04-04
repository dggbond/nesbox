import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_nes/flutter_nes.dart';
import 'package:path/path.dart' as path;
import 'dart:io' show Platform, File;

void main() {
  test('nes emulator load nes file', () async {
    final emulator = new NesEmulator();
    String filepath = path.join(path.dirname(Platform.script.path), 'test/Megaman.nes');

    emulator.loadRom(File(filepath).readAsBytesSync());
    emulator.run();
  });

  test('nes emulator load test program', () {
    final emulator = new NesEmulator();

    emulator.loadRom(Uint8List.fromList([
      0xa9, 0x10, // LDA #$10     -> A = #$10
      0x85, 0x20, // STA $20      -> $20 = #$10
      0xa9, 0x01, // LDA #$1      -> A = #$1
      0x65, 0x20, // ADC $20      -> A = #$11
      0x85, 0x21, // STA $21      -> $21=#$11
      0xe6, 0x21, // INC $21      -> $21=#$12
      0xa4, 0x21, // LDY $21      -> Y=#$12
      0xc8, // INY          -> Y=#$13
      0x00, // BRK
    ]));
    emulator.run();
  });
}
