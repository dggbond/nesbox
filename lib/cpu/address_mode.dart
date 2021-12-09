library flutter_nes.cpu;

import 'cpu.dart';

typedef List<int> AddressMode(CPU cpu);

// one page is 8-bit size;
bool isPageCrossed(int addr1, int addr2) {
  return addr1 & 0xff00 != addr2 & 0xff00;
}

// Addressing mode functions
// see: https://wiki.nesdev.com/w/index.php/CPU_addressing_modes
List<int> ZeroPage(CPU cpu) {
  int byte1 = cpu.read(cpu.regPC++);

  cpu.address = byte1 & 0xff;

  return [byte1, null];
}

List<int> ZeroPageX(CPU cpu) {
  int byte1 = cpu.read(cpu.regPC++);

  cpu.address = (byte1 + cpu.regX) & 0xff;

  return [byte1, null];
}

List<int> ZeroPageY(CPU cpu) {
  int byte1 = cpu.read(cpu.regPC++);

  cpu.address = (byte1 + cpu.regY) & 0xff;

  return [byte1, null];
}

List<int> Absolute(CPU cpu) {
  int byte1 = cpu.read(cpu.regPC++);
  int byte2 = cpu.read(cpu.regPC++);

  cpu.address = byte2 << 8 | byte1;

  return [byte1, byte2];
}

List<int> AbsoluteX(CPU cpu) {
  int byte1 = cpu.read(cpu.regPC++);
  int byte2 = cpu.read(cpu.regPC++);

  cpu.address = (byte2 << 8 | byte1) + cpu.regX;

  if (isPageCrossed(cpu.address, cpu.address - cpu.regX) && cpu.op.increaseCycleWhenCrossPage) cpu.cycles++;

  return [byte1, byte2];
}

List<int> AbsoluteY(CPU cpu) {
  int byte1 = cpu.read(cpu.regPC++);
  int byte2 = cpu.read(cpu.regPC++);

  cpu.address = (byte2 << 8 | byte1) + cpu.regY;

  if (isPageCrossed(cpu.address, cpu.address - cpu.regY) && cpu.op.increaseCycleWhenCrossPage) cpu.cycles++;

  return [byte1, byte2];
}

List<int> Implied(CPU cpu) => [null, null];
List<int> Accumulator(CPU cpu) => [null, null];

List<int> Immediate(CPU cpu) {
  cpu.address = cpu.regPC;

  int byte1 = cpu.read(cpu.regPC++);

  return [byte1, null];
}

List<int> Relative(CPU cpu) {
  // offset is a signed integer
  int byte1 = cpu.read(cpu.regPC++);

  int offset = byte1 >= 0x80 ? byte1 - 0x100 : byte1;
  cpu.address = cpu.regPC + offset;

  return [byte1, null];
}

List<int> Indirect(CPU cpu) {
  int byte1 = cpu.read(cpu.regPC++);
  int byte2 = cpu.read(cpu.regPC++);

  cpu.address = cpu.read16BitUncrossPage((byte2 << 8 | byte1));

  return [byte1, byte2];
}

List<int> IndexedIndirect(CPU cpu) {
  int byte1 = cpu.read(cpu.regPC++);

  cpu.address = cpu.read16BitUncrossPage((byte1 + cpu.regX) & 0xff);

  return [byte1, null];
}

List<int> IndirectIndexed(CPU cpu) {
  int byte1 = cpu.read(cpu.regPC++);
  cpu.address = cpu.read16BitUncrossPage(byte1) + cpu.regY;

  if (isPageCrossed(cpu.address, cpu.address - cpu.regY) && cpu.op.increaseCycleWhenCrossPage) cpu.cycles++;

  return [byte1, null];
}
