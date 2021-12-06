import 'cpu.dart';
import 'util/util.dart';

// one page is 8-bit size;
bool isPageCrossed(int addr1, int addr2) {
  return addr1 & 0xff00 != addr2 & 0xff00;
}

// Addressing mode functions
// see: https://wiki.nesdev.com/w/index.php/CPU_addressing_modes
ZeroPage(CPU cpu) {
  cpu.address = cpu.byte1 = cpu.read(cpu.regPC++) & 0xff;
  cpu.fetched = cpu.read(cpu.address);
}

ZeroPageX(CPU cpu) {
  cpu.byte1 = cpu.read(cpu.regPC++);
  cpu.address = (cpu.byte1 + cpu.regX) & 0xff;
  cpu.fetched = cpu.read(cpu.address);
}

ZeroPageY(CPU cpu) {
  cpu.byte1 = cpu.read(cpu.regPC++);
  cpu.address = (cpu.byte1 + cpu.regY) & 0xff;
  cpu.fetched = cpu.read(cpu.address);
}

Absolute(CPU cpu) {
  cpu.byte1 = cpu.read(cpu.regPC++);
  cpu.byte2 = cpu.read(cpu.regPC++);

  cpu.address = cpu.byte2 << 8 | cpu.byte1;
  cpu.fetched = cpu.read(cpu.address);
}

AbsoluteX(CPU cpu) {
  cpu.byte1 = cpu.read(cpu.regPC++);
  cpu.byte2 = cpu.read(cpu.regPC++);

  cpu.address = (cpu.byte2 << 8 | cpu.byte1) + cpu.regX;
  cpu.fetched = cpu.read(cpu.address);

  if (isPageCrossed(cpu.address, cpu.address - cpu.regX) && cpu.op.increaseCycleWhenCrossPage) cpu.cycles++;
}

AbsoluteY(CPU cpu) {
  cpu.byte1 = cpu.read(cpu.regPC++);
  cpu.byte2 = cpu.read(cpu.regPC++);

  cpu.address = (cpu.byte2 << 8 | cpu.byte1) + cpu.regY;
  cpu.fetched = cpu.read(cpu.address);

  if (isPageCrossed(cpu.address, cpu.address - cpu.regY) && cpu.op.increaseCycleWhenCrossPage) cpu.cycles++;
}

Indirect(CPU cpu) {
  cpu.byte1 = cpu.read(cpu.regPC++);
  cpu.byte2 = cpu.read(cpu.regPC++);

  cpu.address = cpu.read16BitUncrossPage((cpu.byte2 << 8 | cpu.byte1));
  cpu.fetched = cpu.read(cpu.address);
}

Implied(CPU cpu) {}
Accumulator(CPU cpu) {
  cpu.fetched = cpu.regA;
}

Immediate(CPU cpu) {
  cpu.byte1 = cpu.read(cpu.regPC);
  cpu.address = cpu.regPC++;
  cpu.fetched = cpu.read(cpu.address);
}

Relative(CPU cpu) {
  // offset is a signed integer
  cpu.byte1 = cpu.read(cpu.regPC++);

  int offset = cpu.byte1 >= 0x80 ? cpu.byte1 - 0x100 : cpu.byte1;
  cpu.address = cpu.regPC + offset;
  cpu.fetched = cpu.read(cpu.address);
}

IndexedIndirect(CPU cpu) {
  cpu.byte1 = cpu.read(cpu.regPC++);

  cpu.address = cpu.read16BitUncrossPage((cpu.byte1 + cpu.regX) & 0xff);
  cpu.fetched = cpu.read(cpu.address);
}

IndirectIndexed(CPU cpu) {
  cpu.byte1 = cpu.read(cpu.regPC++);
  cpu.address = cpu.read16BitUncrossPage(cpu.byte1) + cpu.regY;
  cpu.fetched = cpu.read(cpu.address);

  if (isPageCrossed(cpu.address, cpu.address - cpu.regY) && cpu.op.increaseCycleWhenCrossPage) cpu.cycles++;
}

ADC(CPU cpu) {
  int tmp = cpu.regA + cpu.fetched + cpu.fCarry;

  // overflow is basically negative + negative = positive
  // postive + positive = negative
  bool overflow = (tmp ^ cpu.regA) & 0x80 != 0 && (tmp ^ cpu.fetched) & 0x80 != 0;

  cpu.fCarry = tmp > 0xff ? 1 : 0;
  cpu.fOverflow = overflow ? 1 : 0;
  cpu.fZero = tmp.getZeroBit();
  cpu.fNegative = tmp.getBit(7);

  cpu.regA = tmp & 0xff;
}

AND(CPU cpu) {
  cpu.regA &= cpu.fetched;

  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

ASL(CPU cpu) {
  cpu.fCarry = cpu.fetched.getBit(7);

  cpu.fetched = (cpu.fetched << 1) & 0xff;

  if (cpu.op.mode == Accumulator) {
    cpu.regA = cpu.fetched;
  } else {
    cpu.write(cpu.address, cpu.fetched);
  }

  cpu.fZero = cpu.fetched.getZeroBit();
  cpu.fNegative = cpu.fetched.getBit(7);
}

BIT(CPU cpu) {
  int test = cpu.fetched & cpu.regA;

  cpu.fZero = test.getZeroBit();
  cpu.fOverflow = cpu.fetched.getBit(6);
  cpu.fNegative = cpu.fetched.getBit(7);
}

BCC(CPU cpu) {
  if (cpu.fCarry == 0) cpu.branchSuccess();
}

BCS(CPU cpu) {
  if (cpu.fCarry == 1) cpu.branchSuccess();
}

BEQ(CPU cpu) {
  if (cpu.fZero == 1) cpu.branchSuccess();
}

BMI(CPU cpu) {
  if (cpu.fNegative == 1) cpu.branchSuccess();
}

BNE(CPU cpu) {
  if (cpu.fZero == 0) cpu.branchSuccess();
}

BPL(CPU cpu) {
  if (cpu.fNegative == 0) cpu.branchSuccess();
}

BVC(CPU cpu) {
  if (cpu.fOverflow == 0) cpu.branchSuccess();
}

BVS(CPU cpu) {
  if (cpu.fOverflow == 1) cpu.branchSuccess();
}

BRK(CPU cpu) {
  cpu.pushStack16Bit(cpu.regPC + 1);
  cpu.pushStack(cpu.regPS);

  cpu.fInterruptDisable = 1;
  cpu.fBreakCommand = 1;

  cpu.regPC = cpu.read16Bit(0xfffe);
}

CLC(CPU cpu) => cpu.fCarry = 0;
CLD(CPU cpu) => cpu.fDecimalMode = 0;
CLI(CPU cpu) => cpu.fInterruptDisable = 0;
CLV(CPU cpu) => cpu.fOverflow = 0;

CMP(CPU cpu) {
  int tmp = cpu.regA - cpu.fetched;

  cpu.fCarry = tmp >= 0 ? 1 : 0;
  cpu.fZero = tmp.getZeroBit();
  cpu.fNegative = tmp.getBit(7);
}

CPX(CPU cpu) {
  int tmp = cpu.regX - cpu.fetched;

  cpu.fCarry = tmp >= 0 ? 1 : 0;
  cpu.fZero = tmp.getZeroBit();
  cpu.fNegative = tmp.getBit(7);
}

CPY(CPU cpu) {
  int tmp = cpu.regY - cpu.fetched;

  cpu.fCarry = tmp >= 0 ? 1 : 0;
  cpu.fZero = tmp.getZeroBit();
  cpu.fNegative = tmp.getBit(7);
}

DEC(CPU cpu) {
  cpu.fetched--;
  cpu.fetched &= 0xff;
  cpu.write(cpu.address, cpu.fetched & 0xff);

  cpu.fZero = cpu.fetched.getZeroBit();
  cpu.fNegative = cpu.fetched.getBit(7);
}

DEX(CPU cpu) {
  cpu.regX = (cpu.regX - 1) & 0xff;

  cpu.fZero = cpu.regX.getZeroBit();
  cpu.fNegative = cpu.regX.getBit(7);
}

DEY(CPU cpu) {
  cpu.regY = (cpu.regY - 1) & 0xff;

  cpu.fZero = cpu.regY.getZeroBit();
  cpu.fNegative = cpu.regY.getBit(7);
}

EOR(CPU cpu) {
  cpu.regA ^= cpu.fetched;

  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

INC(CPU cpu) {
  cpu.fetched++;
  cpu.fetched &= 0xff;

  cpu.write(cpu.address, cpu.fetched & 0xff);

  cpu.fZero = cpu.fetched.getZeroBit();
  cpu.fNegative = cpu.fetched.getBit(7);
}

INX(CPU cpu) {
  cpu.regX = (cpu.regX + 1) & 0xff;

  cpu.fZero = cpu.regX.getZeroBit();
  cpu.fNegative = cpu.regX.getBit(7);
}

INY(CPU cpu) {
  cpu.regY = (cpu.regY + 1) & 0xff;

  cpu.fZero = cpu.regY.getZeroBit();
  cpu.fNegative = cpu.regY.getBit(7);
}

JMP(CPU cpu) => cpu.regPC = cpu.address;
JSR(CPU cpu) {
  cpu.pushStack16Bit(cpu.regPC - 1);
  cpu.regPC = cpu.address;
}

LDA(CPU cpu) {
  cpu.regA = cpu.fetched;

  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

LDX(CPU cpu) {
  cpu.regX = cpu.fetched;

  cpu.fZero = cpu.regX.getZeroBit();
  cpu.fNegative = cpu.regX.getBit(7);
}

LDY(CPU cpu) {
  cpu.regY = cpu.fetched;

  cpu.fZero = cpu.regY.getZeroBit();
  cpu.fNegative = cpu.regY.getBit(7);
}

LSR(CPU cpu) {
  cpu.fCarry = cpu.fetched.getBit(0);
  cpu.fetched = (cpu.fetched >> 1) & 0xff;

  if (cpu.op.mode == Accumulator) {
    cpu.regA = cpu.fetched;
  } else {
    cpu.write(cpu.address, cpu.fetched);
  }

  cpu.fZero = cpu.fetched.getZeroBit();
  cpu.fNegative = 0;
}

// NOPs
NOP(CPU cpu) {}
SKB(CPU cpu) {}
IGN(CPU cpu) {}
ORA(CPU cpu) {
  cpu.regA |= cpu.fetched;

  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

PHA(CPU cpu) => cpu.pushStack(cpu.regA);

// with the breakCommand flag and bit 5 set to 1.
PHP(CPU cpu) {
  int value = cpu.regPS.setBit(4, 1).setBit(5, 1);
  cpu.pushStack(value);
}

PLA(CPU cpu) {
  cpu.regA = cpu.popStack();

  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

// with the breakCommand flag and bit 5 ignored.
PLP(CPU cpu) {
  int value = cpu.popStack().setBit(4, cpu.fBreakCommand).setBit(5, cpu.fUnused);
  cpu.regPS = value;
}

ROL(CPU cpu) {
  int oldCarry = cpu.fCarry;

  cpu.fCarry = cpu.fetched.getBit(7);
  cpu.fetched = (cpu.fetched << 1).setBit(0, oldCarry);

  if (cpu.op.mode == Accumulator) {
    cpu.regA = cpu.fetched & 0xff;
    cpu.fZero = cpu.regA.getZeroBit();
  } else {
    cpu.write(cpu.address, cpu.fetched);
  }

  cpu.fNegative = cpu.fetched.getBit(7);
}

ROR(CPU cpu) {
  int oldCarry = cpu.fCarry;

  cpu.fCarry = cpu.fetched.getBit(0);
  cpu.fetched = (cpu.fetched >> 1).setBit(7, oldCarry);

  if (cpu.op.mode == Accumulator) {
    cpu.regA = cpu.fetched;
    cpu.fZero = cpu.regA.getZeroBit();
  } else {
    cpu.write(cpu.address, cpu.fetched);
  }

  cpu.fNegative = cpu.fetched.getBit(7);
}

RTI(CPU cpu) {
  int value = cpu.popStack().setBit(4, cpu.fBreakCommand).setBit(5, cpu.fUnused);
  cpu.regPS = value;
  cpu.regPC = cpu.popStack16Bit();
}

RTS(CPU cpu) => cpu.regPC = cpu.popStack16Bit() + 1;
SBC(CPU cpu) {
  int tmp = cpu.regA - cpu.fetched - (1 - cpu.fCarry);

  bool overflow = (tmp ^ cpu.regA) & 0x80 != 0 && (cpu.regA ^ cpu.fetched) & 0x80 != 0;

  cpu.fCarry = tmp >= 0 ? 1 : 0;
  cpu.fZero = tmp.getZeroBit();
  cpu.fOverflow = overflow ? 1 : 0;
  cpu.fNegative = tmp.getBit(7);

  cpu.regA = tmp & 0xff;
}

SEC(CPU cpu) => cpu.fCarry = 1;
SED(CPU cpu) => cpu.fDecimalMode = 1;
SEI(CPU cpu) => cpu.fInterruptDisable = 1;
STA(CPU cpu) => cpu.write(cpu.address, cpu.regA);
STX(CPU cpu) => cpu.write(cpu.address, cpu.regX);
STY(CPU cpu) => cpu.write(cpu.address, cpu.regY);

TAX(CPU cpu) {
  cpu.regX = cpu.regA;

  cpu.fZero = cpu.regX.getZeroBit();
  cpu.fNegative = cpu.regX.getBit(7);
}

TAY(CPU cpu) {
  cpu.regY = cpu.regA;

  cpu.fZero = cpu.regY.getZeroBit();
  cpu.fNegative = cpu.regY.getBit(7);
}

TSX(CPU cpu) {
  cpu.regX = cpu.regSP;

  cpu.fZero = cpu.regX.getZeroBit();
  cpu.fNegative = cpu.regX.getBit(7);
}

TXA(CPU cpu) {
  cpu.regA = cpu.regX;

  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

TXS(CPU cpu) => cpu.regSP = cpu.regX;
TYA(CPU cpu) {
  cpu.regA = cpu.regY;

  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

ALR(CPU cpu) {
  AND(cpu);
  LSR(cpu);
}

ANC(CPU cpu) {
  cpu.regA &= cpu.fetched;

  cpu.fCarry = cpu.regA.getBit(7);
  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

ARR(CPU cpu) {
  AND(cpu);
  ROR(cpu);
}

AXS(CPU cpu) {
  cpu.regX &= cpu.regA;

  cpu.fCarry = 0;
  cpu.fZero = cpu.regX.getZeroBit();
  cpu.fNegative = cpu.regX.getBit(7);
}

LAX(CPU cpu) {
  cpu.regX = cpu.regA = cpu.fetched;

  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

SAX(CPU cpu) {
  cpu.write(cpu.address, cpu.regX & cpu.regA);
}

DCP(CPU cpu) {
  DEC(cpu);
  CMP(cpu);
}

ISC(CPU cpu) {
  INC(cpu);
  SBC(cpu);
}

RLA(CPU cpu) {
  ROL(cpu);
  AND(cpu);
}

RRA(CPU cpu) {
  ROR(cpu);
  ADC(cpu);
}

SLO(CPU cpu) {
  ASL(cpu);
  ORA(cpu);
}

SRE(CPU cpu) {
  LSR(cpu);
  EOR(cpu);
}

class Op {
  const Op(this.instruction, this.abbr, this.mode, this.cycles, [this.increaseCycleWhenCrossPage = false]);

  final Function instruction;
  final String abbr;
  final Function mode;
  final int cycles;
  final bool increaseCycleWhenCrossPage;
}

const Map<int, Op> CPU_OPS = {
  0x69: Op(ADC, 'ADC', Immediate, 2),
  0x65: Op(ADC, 'ADC', ZeroPage, 3),
  0x75: Op(ADC, 'ADC', ZeroPageX, 4),
  0x6d: Op(ADC, 'ADC', Absolute, 4),
  0x7d: Op(ADC, 'ADC', AbsoluteX, 4, true),
  0x79: Op(ADC, 'ADC', AbsoluteY, 4, true),
  0x61: Op(ADC, 'ADC', IndexedIndirect, 6),
  0x71: Op(ADC, 'ADC', IndirectIndexed, 5, true),
  0x29: Op(AND, 'AND', Immediate, 2),
  0x25: Op(AND, 'AND', ZeroPage, 3),
  0x35: Op(AND, 'AND', ZeroPageX, 4),
  0x2d: Op(AND, 'AND', Absolute, 4),
  0x3d: Op(AND, 'AND', AbsoluteX, 4, true),
  0x39: Op(AND, 'AND', AbsoluteY, 4, true),
  0x21: Op(AND, 'AND', IndexedIndirect, 6),
  0x31: Op(AND, 'AND', IndirectIndexed, 5, true),
  0x0a: Op(ASL, 'ASL', Accumulator, 2),
  0x06: Op(ASL, 'ASL', ZeroPage, 5),
  0x16: Op(ASL, 'ASL', ZeroPageX, 6),
  0x0e: Op(ASL, 'ASL', Absolute, 6),
  0x1e: Op(ASL, 'ASL', AbsoluteX, 7),
  0x90: Op(BCC, 'BCC', Relative, 2, true),
  0xb0: Op(BCS, 'BCS', Relative, 2, true),
  0xf0: Op(BEQ, 'BEQ', Relative, 2, true),
  0x24: Op(BIT, 'BIT', ZeroPage, 3),
  0x2c: Op(BIT, 'BIT', Absolute, 4),
  0x30: Op(BMI, 'BMI', Relative, 2, true),
  0xd0: Op(BNE, 'BNE', Relative, 2, true),
  0x10: Op(BPL, 'BPL', Relative, 2, true),
  0x00: Op(BRK, 'BRK', Implied, 7),
  0x50: Op(BVC, 'BVC', Relative, 2, true),
  0x70: Op(BVS, 'BVS', Relative, 2, true),
  0x18: Op(CLC, 'CLC', Implied, 2),
  0xd8: Op(CLD, 'CLD', Implied, 2),
  0x58: Op(CLI, 'CLI', Implied, 2),
  0xb8: Op(CLV, 'CLV', Implied, 2),
  0xc9: Op(CMP, 'CMP', Immediate, 2),
  0xc5: Op(CMP, 'CMP', ZeroPage, 3),
  0xd5: Op(CMP, 'CMP', ZeroPageX, 4),
  0xcd: Op(CMP, 'CMP', Absolute, 4),
  0xdd: Op(CMP, 'CMP', AbsoluteX, 4, true),
  0xd9: Op(CMP, 'CMP', AbsoluteY, 4, true),
  0xc1: Op(CMP, 'CMP', IndexedIndirect, 6, true),
  0xd1: Op(CMP, 'CMP', IndirectIndexed, 5, true),
  0xe0: Op(CPX, 'CPX', Immediate, 2),
  0xe4: Op(CPX, 'CPX', ZeroPage, 3),
  0xec: Op(CPX, 'CPX', Absolute, 4),
  0xc0: Op(CPY, 'CPY', Immediate, 2),
  0xc4: Op(CPY, 'CPY', ZeroPage, 3),
  0xcc: Op(CPY, 'CPY', Absolute, 4),
  0xc6: Op(DEC, 'DEC', ZeroPage, 5),
  0xd6: Op(DEC, 'DEC', ZeroPageX, 6),
  0xce: Op(DEC, 'DEC', Absolute, 6),
  0xde: Op(DEC, 'DEC', AbsoluteX, 7),
  0xca: Op(DEX, 'DEX', Implied, 2),
  0x88: Op(DEY, 'DEY', Implied, 2),
  0x49: Op(EOR, 'EOR', Immediate, 2),
  0x45: Op(EOR, 'EOR', ZeroPage, 3),
  0x55: Op(EOR, 'EOR', ZeroPageX, 4),
  0x4d: Op(EOR, 'EOR', Absolute, 4),
  0x5d: Op(EOR, 'EOR', AbsoluteX, 4, true),
  0x59: Op(EOR, 'EOR', AbsoluteY, 4, true),
  0x41: Op(EOR, 'EOR', IndexedIndirect, 6),
  0x51: Op(EOR, 'EOR', IndirectIndexed, 5, true),
  0xe6: Op(INC, 'INC', ZeroPage, 5),
  0xf6: Op(INC, 'INC', ZeroPageX, 6),
  0xee: Op(INC, 'INC', Absolute, 6),
  0xfe: Op(INC, 'INC', AbsoluteX, 7),
  0xe8: Op(INX, 'INX', Implied, 2),
  0xc8: Op(INY, 'INY', Implied, 2),
  0x4c: Op(JMP, 'JMP', Absolute, 3),
  0x6c: Op(JMP, 'JMP', Indirect, 5),
  0x20: Op(JSR, 'JSR', Absolute, 6),
  0xa9: Op(LDA, 'LDA', Immediate, 2),
  0xa5: Op(LDA, 'LDA', ZeroPage, 3),
  0xb5: Op(LDA, 'LDA', ZeroPageX, 4),
  0xad: Op(LDA, 'LDA', Absolute, 4),
  0xbd: Op(LDA, 'LDA', AbsoluteX, 4, true),
  0xb9: Op(LDA, 'LDA', AbsoluteY, 4, true),
  0xa1: Op(LDA, 'LDA', IndexedIndirect, 6),
  0xb1: Op(LDA, 'LDA', IndirectIndexed, 5, true),
  0xa2: Op(LDX, 'LDX', Immediate, 2),
  0xa6: Op(LDX, 'LDX', ZeroPage, 3),
  0xb6: Op(LDX, 'LDX', ZeroPageY, 4),
  0xae: Op(LDX, 'LDX', Absolute, 4),
  0xbe: Op(LDX, 'LDX', AbsoluteY, 4, true),
  0xa0: Op(LDY, 'LDY', Immediate, 2),
  0xa4: Op(LDY, 'LDY', ZeroPage, 3),
  0xb4: Op(LDY, 'LDY', ZeroPageX, 4),
  0xac: Op(LDY, 'LDY', Absolute, 4),
  0xbc: Op(LDY, 'LDY', AbsoluteX, 4, true),
  0x4a: Op(LSR, 'LSR', Accumulator, 2),
  0x46: Op(LSR, 'LSR', ZeroPage, 5),
  0x56: Op(LSR, 'LSR', ZeroPageX, 6),
  0x4e: Op(LSR, 'LSR', Absolute, 6),
  0x5e: Op(LSR, 'LSR', AbsoluteX, 7),
  0x1a: Op(NOP, '*NOP', Implied, 2),
  0x3a: Op(NOP, '*NOP', Implied, 2),
  0x5a: Op(NOP, '*NOP', Implied, 2),
  0x7a: Op(NOP, '*NOP', Implied, 2),
  0xda: Op(NOP, '*NOP', Implied, 2),
  0xea: Op(NOP, 'NOP', Implied, 2),
  0xfa: Op(NOP, '*NOP', Implied, 2),
  0x09: Op(ORA, 'ORA', Immediate, 2),
  0x05: Op(ORA, 'ORA', ZeroPage, 3),
  0x15: Op(ORA, 'ORA', ZeroPageX, 4),
  0x0d: Op(ORA, 'ORA', Absolute, 4),
  0x1d: Op(ORA, 'ORA', AbsoluteX, 4, true),
  0x19: Op(ORA, 'ORA', AbsoluteY, 4, true),
  0x01: Op(ORA, 'ORA', IndexedIndirect, 6),
  0x11: Op(ORA, 'ORA', IndirectIndexed, 5, true),
  0x48: Op(PHA, 'PHA', Implied, 3),
  0x08: Op(PHP, 'PHP', Implied, 3),
  0x68: Op(PLA, 'PLA', Implied, 4),
  0x28: Op(PLP, 'PLP', Implied, 4),
  0x2a: Op(ROL, 'ROL', Accumulator, 2),
  0x26: Op(ROL, 'ROL', ZeroPage, 5),
  0x36: Op(ROL, 'ROL', ZeroPageX, 6),
  0x2e: Op(ROL, 'ROL', Absolute, 6),
  0x3e: Op(ROL, 'ROL', AbsoluteX, 7),
  0x6a: Op(ROR, 'ROR', Accumulator, 2),
  0x66: Op(ROR, 'ROR', ZeroPage, 5),
  0x76: Op(ROR, 'ROR', ZeroPageX, 6),
  0x6e: Op(ROR, 'ROR', Absolute, 6),
  0x7e: Op(ROR, 'ROR', AbsoluteX, 7),
  0x40: Op(RTI, 'RTI', Implied, 6),
  0x60: Op(RTS, 'RTS', Implied, 6),
  0xeb: Op(SBC, '*SBC', Immediate, 2),
  0xe9: Op(SBC, 'SBC', Immediate, 2),
  0xe5: Op(SBC, 'SBC', ZeroPage, 3),
  0xf5: Op(SBC, 'SBC', ZeroPageX, 4),
  0xed: Op(SBC, 'SBC', Absolute, 4),
  0xfd: Op(SBC, 'SBC', AbsoluteX, 4, true),
  0xf9: Op(SBC, 'SBC', AbsoluteY, 4, true),
  0xe1: Op(SBC, 'SBC', IndexedIndirect, 6),
  0xf1: Op(SBC, 'SBC', IndirectIndexed, 5, true),
  0x38: Op(SEC, 'SEC', Implied, 2),
  0xf8: Op(SED, 'SED', Implied, 2),
  0x78: Op(SEI, 'SEI', Implied, 2),
  0x85: Op(STA, 'STA', ZeroPage, 3),
  0x95: Op(STA, 'STA', ZeroPageX, 4),
  0x8d: Op(STA, 'STA', Absolute, 4),
  0x9d: Op(STA, 'STA', AbsoluteX, 5),
  0x99: Op(STA, 'STA', AbsoluteY, 5),
  0x81: Op(STA, 'STA', IndexedIndirect, 6),
  0x91: Op(STA, 'STA', IndirectIndexed, 6),
  0x86: Op(STX, 'STX', ZeroPage, 3),
  0x96: Op(STX, 'STX', ZeroPageY, 4),
  0x8e: Op(STX, 'STX', Absolute, 4),
  0x84: Op(STY, 'STY', ZeroPage, 3),
  0x94: Op(STY, 'STY', ZeroPageX, 4),
  0x8c: Op(STY, 'STY', Absolute, 4),
  0xaa: Op(TAX, 'TAX', Implied, 2),
  0xa8: Op(TAY, 'TAY', Implied, 2),
  0xba: Op(TSX, 'TSX', Implied, 2),
  0x8a: Op(TXA, 'TXA', Implied, 2),
  0x9a: Op(TXS, 'TXS', Implied, 2),
  0x98: Op(TYA, 'TYA', Implied, 2),
  0x4b: Op(ALR, 'ALR', Immediate, 2),
  0x0b: Op(ANC, 'ANC', Immediate, 2),
  0x2b: Op(ANC, 'ANC', Immediate, 2),
  0x6b: Op(ARR, 'ARR', Immediate, 2),
  0xcb: Op(AXS, 'AXS', Immediate, 2),
  0xa7: Op(LAX, '*LAX', ZeroPage, 3),
  0xb7: Op(LAX, '*LAX', ZeroPageY, 4),
  0xaf: Op(LAX, '*LAX', Absolute, 4),
  0xbf: Op(LAX, '*LAX', AbsoluteY, 4, true),
  0xa3: Op(LAX, '*LAX', IndexedIndirect, 6),
  0xb3: Op(LAX, '*LAX', IndirectIndexed, 5, true),
  0x87: Op(SAX, '*SAX', ZeroPage, 3),
  0x97: Op(SAX, '*SAX', ZeroPageY, 4),
  0x8f: Op(SAX, '*SAX', Absolute, 4),
  0x83: Op(SAX, '*SAX', IndexedIndirect, 6, true),
  0xc7: Op(DCP, '*DCP', ZeroPage, 5),
  0xd7: Op(DCP, '*DCP', ZeroPageX, 6),
  0xcf: Op(DCP, '*DCP', Absolute, 6),
  0xdf: Op(DCP, '*DCP', AbsoluteX, 7),
  0xdb: Op(DCP, '*DCP', AbsoluteY, 7),
  0xc3: Op(DCP, '*DCP', IndexedIndirect, 8),
  0xd3: Op(DCP, '*DCP', IndirectIndexed, 8),
  0xe7: Op(ISC, '*ISB', ZeroPage, 5),
  0xf7: Op(ISC, '*ISB', ZeroPageX, 6),
  0xef: Op(ISC, '*ISB', Absolute, 6),
  0xff: Op(ISC, '*ISB', AbsoluteX, 7),
  0xfb: Op(ISC, '*ISB', AbsoluteY, 7),
  0xe3: Op(ISC, '*ISB', IndexedIndirect, 8),
  0xf3: Op(ISC, '*ISB', IndirectIndexed, 8),
  0x27: Op(RLA, '*RLA', ZeroPage, 5),
  0x37: Op(RLA, '*RLA', ZeroPageX, 6),
  0x2f: Op(RLA, '*RLA', Absolute, 6),
  0x3f: Op(RLA, '*RLA', AbsoluteX, 7),
  0x3b: Op(RLA, '*RLA', AbsoluteY, 7),
  0x23: Op(RLA, '*RLA', IndexedIndirect, 8),
  0x33: Op(RLA, '*RLA', IndirectIndexed, 8),
  0x67: Op(RRA, '*RRA', ZeroPage, 5),
  0x77: Op(RRA, '*RRA', ZeroPageX, 6),
  0x6f: Op(RRA, '*RRA', Absolute, 6),
  0x7f: Op(RRA, '*RRA', AbsoluteX, 7),
  0x7b: Op(RRA, '*RRA', AbsoluteY, 7),
  0x63: Op(RRA, '*RRA', IndexedIndirect, 8),
  0x73: Op(RRA, '*RRA', IndirectIndexed, 8),
  0x07: Op(SLO, '*SLO', ZeroPage, 5),
  0x17: Op(SLO, '*SLO', ZeroPageX, 6),
  0x0f: Op(SLO, '*SLO', Absolute, 6),
  0x1f: Op(SLO, '*SLO', AbsoluteX, 7),
  0x1b: Op(SLO, '*SLO', AbsoluteY, 7),
  0x03: Op(SLO, '*SLO', IndexedIndirect, 8),
  0x13: Op(SLO, '*SLO', IndirectIndexed, 8),
  0x47: Op(SRE, '*SRE', ZeroPage, 5),
  0x57: Op(SRE, '*SRE', ZeroPageX, 6),
  0x4f: Op(SRE, '*SRE', Absolute, 6),
  0x5f: Op(SRE, '*SRE', AbsoluteX, 7),
  0x5b: Op(SRE, '*SRE', AbsoluteY, 7),
  0x43: Op(SRE, '*SRE', IndexedIndirect, 8),
  0x53: Op(SRE, '*SRE', IndirectIndexed, 8),
  0x80: Op(SKB, '*NOP', Immediate, 2),
  0x82: Op(SKB, '*NOP', Immediate, 2),
  0x89: Op(SKB, '*NOP', Immediate, 2),
  0xc2: Op(SKB, '*NOP', Immediate, 2),
  0xe2: Op(SKB, '*NOP', Immediate, 2),
  0x0c: Op(IGN, '*NOP', Absolute, 4),
  0x1c: Op(IGN, '*NOP', AbsoluteX, 4, true),
  0x3c: Op(IGN, '*NOP', AbsoluteX, 4, true),
  0x5c: Op(IGN, '*NOP', AbsoluteX, 4, true),
  0x7c: Op(IGN, '*NOP', AbsoluteX, 4, true),
  0xdc: Op(IGN, '*NOP', AbsoluteX, 4, true),
  0xfc: Op(IGN, '*NOP', AbsoluteX, 4, true),
  0x04: Op(IGN, '*NOP', ZeroPage, 3),
  0x44: Op(IGN, '*NOP', ZeroPage, 3),
  0x64: Op(IGN, '*NOP', ZeroPage, 3),
  0x14: Op(IGN, '*NOP', ZeroPageX, 4),
  0x34: Op(IGN, '*NOP', ZeroPageX, 4),
  0x54: Op(IGN, '*NOP', ZeroPageX, 4),
  0x74: Op(IGN, '*NOP', ZeroPageX, 4),
  0xd4: Op(IGN, '*NOP', ZeroPageX, 4),
  0xf4: Op(IGN, '*NOP', ZeroPageX, 4),
};
