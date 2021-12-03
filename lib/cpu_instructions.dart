import 'cpu.dart';
import 'util/util.dart';

// one page is 8-bit size;
bool isPageCrossed(int addr1, int addr2) {
  return addr1 & 0xff00 != addr2 & 0xff00;
}

// Addressing mode functions
// see: https://wiki.nesdev.com/w/index.php/CPU_addressing_modes
ZeroPage(CPU cpu) {
  cpu.absAddr = cpu.read(cpu.regPC++) % 0xff;
}

ZeroPageX(CPU cpu) {
  cpu.absAddr = (cpu.read(cpu.regPC++) + cpu.regX) % 0xff;
}

ZeroPageY(CPU cpu) {
  cpu.absAddr = (cpu.read(cpu.regPC++) + cpu.regY) % 0xff;
}

Absolute(CPU cpu) {
  cpu.absAddr = cpu.read16Bit(cpu.regPC);
  cpu.regPC += 2;
}

AbsoluteX(CPU cpu) {
  cpu.absAddr = cpu.read16Bit(cpu.regPC) + cpu.regX;
  cpu.regPC += 2;

  if (isPageCrossed(cpu.absAddr, cpu.absAddr - cpu.regX)) cpu.cycles++;
}

AbsoluteY(CPU cpu) {
  cpu.absAddr = cpu.read16Bit(cpu.regPC) + cpu.regY;
  cpu.regPC += 2;

  if (isPageCrossed(cpu.absAddr, cpu.absAddr - cpu.regY)) cpu.cycles++;
}

Indirect(CPU cpu) {
  cpu.absAddr = cpu.read16Bit(cpu.read16Bit(cpu.regPC));
  cpu.regPC += 2;
}

Implied(CPU cpu) {}
Accumulator(CPU cpu) {}

Immediate(CPU cpu) {
  cpu.absAddr = cpu.regPC++;
}

Relative(CPU cpu) {
  // offset is a signed integer
  int offset = cpu.read(cpu.regPC++);

  cpu.relAddr = offset >= 0x80 ? offset - 0x100 : offset;
}

IndexedIndirect(CPU cpu) {
  cpu.absAddr = cpu.read16Bit(cpu.read((cpu.regPC++ + cpu.regX) % 0xff));
}

IndirectIndexed(CPU cpu) {
  cpu.absAddr = cpu.read16Bit(cpu.read(cpu.regPC++)) + cpu.regY;

  if (isPageCrossed(cpu.absAddr, cpu.absAddr - cpu.regY)) cpu.cycles++;
}

ADC(CPU cpu) {
  int fetched = cpu.fetch();
  int tmp = cpu.regA + fetched + cpu.fCarry;

  // overflow is basically negative + negative = positive
  // postive + positive = negative
  int overflow = (tmp ^ cpu.regA) & (tmp ^ fetched) & 0x80;

  cpu.fCarry = tmp > 0xff ? 1 : 0;
  cpu.fOverflow = overflow >> 7;
  cpu.fZero = tmp.getZeroBit();
  cpu.fNegative = tmp.getBit(7);

  cpu.regA = tmp & 0xff;
}

AND(CPU cpu) {
  int fetched = cpu.fetch();
  cpu.regA &= fetched;

  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

ASL(CPU cpu) {
  int fetched = cpu.fetch();
  int tmp = (fetched << 1) & 0xff;

  if (cpu.op.mode == Accumulator) {
    cpu.regA = tmp;
  } else {
    cpu.write(cpu.absAddr, tmp);
  }

  cpu.fCarry = fetched.getBit(7);
  cpu.fZero = tmp.getZeroBit();
  cpu.fNegative = tmp.getBit(7);
}

BIT(CPU cpu) {
  int fetched = cpu.fetch();
  int test = fetched & cpu.regA;

  cpu.fZero = test.getZeroBit();
  cpu.fOverflow = fetched.getBit(6);
  cpu.fNegative = fetched.getBit(7);
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
  int fetched = cpu.fetch();
  int tmp = cpu.regA - fetched;

  cpu.fCarry = tmp >= 0 ? 1 : 0;
  cpu.fZero = tmp.getZeroBit();
  cpu.fNegative = tmp.getBit(7);
}

CPX(CPU cpu) {
  int fetched = cpu.fetch();
  int tmp = cpu.regX - fetched;

  cpu.fCarry = tmp >= 0 ? 1 : 0;
  cpu.fZero = tmp.getZeroBit();
  cpu.fNegative = tmp.getBit(7);
}

CPY(CPU cpu) {
  int fetched = cpu.fetch();
  int tmp = cpu.regY - fetched;

  cpu.fCarry = tmp >= 0 ? 1 : 0;
  cpu.fZero = tmp.getZeroBit();
  cpu.fNegative = tmp.getBit(7);
}

DEC(CPU cpu) {
  int fetched = cpu.fetch();
  fetched--;
  cpu.write(cpu.absAddr, fetched & 0xff);

  cpu.fZero = fetched.getZeroBit();
  cpu.fNegative = fetched.getBit(7);
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
  int fetched = cpu.fetch();
  cpu.regA ^= fetched;

  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

INC(CPU cpu) {
  int fetched = cpu.fetch();
  fetched++;
  cpu.write(cpu.absAddr, fetched & 0xff);

  cpu.fZero = fetched.getZeroBit();
  cpu.fNegative = fetched.getBit(7);
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

JMP(CPU cpu) => cpu.regPC = cpu.absAddr;
JSR(CPU cpu) {
  cpu.pushStack16Bit(cpu.regPC - 1);
  cpu.regPC = cpu.absAddr;
}

LDA(CPU cpu) {
  int fetched = cpu.fetch();
  cpu.regA = fetched;

  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

LDX(CPU cpu) {
  int fetched = cpu.fetch();
  cpu.regX = fetched;

  cpu.fZero = cpu.regX.getZeroBit();
  cpu.fNegative = cpu.regX.getBit(7);
}

LDY(CPU cpu) {
  int fetched = cpu.fetch();
  cpu.regY = fetched;

  cpu.fZero = cpu.regY.getZeroBit();
  cpu.fNegative = cpu.regY.getBit(7);
}

LSR(CPU cpu) {
  int fetched = cpu.fetch();
  int tmp = (fetched >> 1) & 0xff;

  if (cpu.op.mode == Accumulator) {
    cpu.regA = tmp;
  } else {
    cpu.write(cpu.absAddr, tmp);
  }

  cpu.fCarry = fetched.getBit(7);
  cpu.fZero = tmp.getZeroBit();
  cpu.fNegative = tmp.getBit(7);
}

// NOPs
NOP(CPU cpu) {}
SKB(CPU cpu) {}
IGN(CPU cpu) {}
ORA(CPU cpu) {
  int fetched = cpu.fetch();
  cpu.regA |= fetched;

  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

PHA(CPU cpu) => cpu.pushStack(cpu.regA);
PHP(CPU cpu) => cpu.pushStack(cpu.regPS);
PLA(CPU cpu) {
  cpu.regA = cpu.popStack();

  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

PLP(CPU cpu) => cpu.regPS = cpu.popStack();
ROL(CPU cpu) {
  int fetched = cpu.fetch();
  int tmp = (fetched << 1).setBit(0, cpu.fCarry);

  if (cpu.op.mode == Accumulator) {
    cpu.regA = tmp;
    cpu.fZero = cpu.regA.getZeroBit();
  } else {
    cpu.write(cpu.absAddr, tmp);
  }

  cpu.fCarry = fetched.getBit(7);
  cpu.fNegative = tmp.getBit(7);
}

ROR(CPU cpu) {
  int fetched = cpu.fetch();
  int tmp = (fetched >> 1).setBit(7, cpu.fCarry);

  if (cpu.op.mode == Accumulator) {
    cpu.regA = tmp;
    cpu.fZero = cpu.regA.getZeroBit();
  } else {
    cpu.write(cpu.absAddr, tmp);
  }

  cpu.fCarry = fetched.getBit(0);
  cpu.fNegative = fetched.getBit(7);
}

RTI(CPU cpu) {
  cpu.regPS = cpu.popStack();
  cpu.regPC = cpu.popStack16Bit();

  cpu.fInterruptDisable = 0;
}

RTS(CPU cpu) => cpu.regPC = cpu.popStack16Bit() + 1;
SBC(CPU cpu) {
  int fetched = cpu.fetch();
  int tmp = cpu.regA - fetched - (1 - cpu.fCarry);

  int overflow = (tmp ^ cpu.regA) & (tmp ^ fetched) & 0x80;

  cpu.fCarry = tmp > 0xff ? 0 : 1;
  cpu.fZero = tmp.getZeroBit();
  cpu.fOverflow = overflow >> 7;
  cpu.fNegative = tmp.getBit(7);

  cpu.regA = tmp & 0xff;
}

SEC(CPU cpu) => cpu.fCarry = 1;
SED(CPU cpu) => cpu.fDecimalMode = 1;
SEI(CPU cpu) => cpu.fInterruptDisable = 1;
STA(CPU cpu) => cpu.write(cpu.absAddr, cpu.regA);
STX(CPU cpu) => cpu.write(cpu.absAddr, cpu.regX);
STY(CPU cpu) => cpu.write(cpu.absAddr, cpu.regY);

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
  int fetched = cpu.fetch();
  cpu.regA &= fetched;

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
  int fetched = cpu.fetch();
  cpu.regX = cpu.regA = fetched;

  cpu.fZero = cpu.regA.getZeroBit();
  cpu.fNegative = cpu.regA.getBit(7);
}

SAX(CPU cpu) {
  cpu.regX &= cpu.regA;
  cpu.write(cpu.absAddr, cpu.regX);
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
  const Op(this.instruction, this.mode, this.cycles);

  final Function instruction;
  final Function mode;
  final int cycles;
}

const Map<int, Op> CPU_OPS = {
  0x69: Op(ADC, Immediate, 2),
  0x65: Op(ADC, ZeroPage, 3),
  0x75: Op(ADC, ZeroPageX, 4),
  0x6d: Op(ADC, Absolute, 4),
  0x7d: Op(ADC, AbsoluteX, 4), // cycles +1 if page crossed
  0x79: Op(ADC, AbsoluteY, 4), // cycles +1 if page crossed
  0x61: Op(ADC, IndexedIndirect, 6),
  0x71: Op(ADC, IndirectIndexed, 5), // cycles +1 if page crossed

  0x29: Op(AND, Immediate, 2),
  0x25: Op(AND, ZeroPage, 3),
  0x35: Op(AND, ZeroPageX, 4),
  0x2d: Op(AND, Absolute, 4),
  0x3d: Op(AND, AbsoluteX, 4), // cycles +1 if page crossed
  0x39: Op(AND, AbsoluteY, 4), // cycles +1 if page crossed
  0x21: Op(AND, IndexedIndirect, 6),
  0x31: Op(AND, IndirectIndexed, 5), // cycles +1 if page crossed

  0x0a: Op(ASL, Accumulator, 2),
  0x06: Op(ASL, ZeroPage, 5),
  0x16: Op(ASL, ZeroPageX, 6),
  0x0e: Op(ASL, Absolute, 6),
  0x1e: Op(ASL, AbsoluteX, 7),

  0x90: Op(BCC, Relative, 2), // cycles +1 if branch succeeds +2 if to a new page

  0xb0: Op(BCS, Relative, 2), // cycles +1 if branch succeeds +2 if to a new page

  0xf0: Op(BEQ, Relative, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x24: Op(BIT, ZeroPage, 3),
  0x2c: Op(BIT, Absolute, 4),

  0x30: Op(BMI, Relative, 2), // cycles +1 if branch succeeds +2 if to a new page

  0xd0: Op(BNE, Relative, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x10: Op(BPL, Relative, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x00: Op(BRK, Implied, 7),

  0x50: Op(BVC, Relative, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x70: Op(BVS, Relative, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x18: Op(CLC, Implied, 2),

  0xd8: Op(CLD, Implied, 2),

  0x58: Op(CLI, Implied, 2),

  0xb8: Op(CLV, Implied, 2),

  0xc9: Op(CMP, Immediate, 2),
  0xc5: Op(CMP, ZeroPage, 3),
  0xd5: Op(CMP, ZeroPageX, 4),
  0xcd: Op(CMP, Absolute, 4),
  0xdd: Op(CMP, AbsoluteX, 4), // cycles +1 if page crossed
  0xd9: Op(CMP, AbsoluteY, 4), // cycles +1 if page crossed
  0xc1: Op(CMP, IndexedIndirect, 6),
  0xd1: Op(CMP, IndirectIndexed, 5), // cycles +1 if page crossed

  0xe0: Op(CPX, Immediate, 2),
  0xe4: Op(CPX, ZeroPage, 3),
  0xec: Op(CPX, Absolute, 4),

  0xc0: Op(CPY, Immediate, 2),
  0xc4: Op(CPY, ZeroPage, 3),
  0xcc: Op(CPY, Absolute, 4),

  0xc6: Op(DEC, ZeroPage, 5),
  0xd6: Op(DEC, ZeroPageX, 6),
  0xce: Op(DEC, Absolute, 6),
  0xde: Op(DEC, AbsoluteX, 7),

  0xca: Op(DEX, Implied, 2),

  0x88: Op(DEY, Implied, 2),

  0x49: Op(EOR, Immediate, 2),
  0x45: Op(EOR, ZeroPage, 3),
  0x55: Op(EOR, ZeroPageX, 4),
  0x4d: Op(EOR, Absolute, 4),
  0x5d: Op(EOR, AbsoluteX, 4), // cycles +1 if page crossed
  0x59: Op(EOR, AbsoluteY, 4), // cycles +1 if page crossed
  0x41: Op(EOR, IndexedIndirect, 6),
  0x51: Op(EOR, IndirectIndexed, 5), // cycles +1 if page crossed

  0xe6: Op(INC, ZeroPage, 5),
  0xf6: Op(INC, ZeroPageX, 6),
  0xee: Op(INC, Absolute, 6),
  0xfe: Op(INC, AbsoluteX, 7),

  0xe8: Op(INX, Implied, 2),

  0xc8: Op(INY, Implied, 2),

  0x4c: Op(JMP, Absolute, 3),
  0x6c: Op(JMP, Indirect, 5),

  0x20: Op(JSR, Absolute, 6),

  0xa9: Op(LDA, Immediate, 2),
  0xa5: Op(LDA, ZeroPage, 3),
  0xb5: Op(LDA, ZeroPageX, 4),
  0xad: Op(LDA, Absolute, 4),
  0xbd: Op(LDA, AbsoluteX, 4), // cycles +1 if page crossed
  0xb9: Op(LDA, AbsoluteY, 4), // cycles +1 if page crossed
  0xa1: Op(LDA, IndexedIndirect, 6),
  0xb1: Op(LDA, IndirectIndexed, 5), // cycles +1 if page crossed

  0xa2: Op(LDX, Immediate, 2),
  0xa6: Op(LDX, ZeroPage, 3),
  0xb6: Op(LDX, ZeroPageY, 4),
  0xae: Op(LDX, Absolute, 4),
  0xbe: Op(LDX, AbsoluteY, 4), // cycles + 1 if page crossed

  0xa0: Op(LDY, Immediate, 2),
  0xa4: Op(LDY, ZeroPage, 3),
  0xb4: Op(LDY, ZeroPageY, 4),
  0xac: Op(LDY, Absolute, 4),
  0xbc: Op(LDY, AbsoluteY, 4), // cycles + 1 if page crossed

  0x4a: Op(LSR, Accumulator, 2),
  0x46: Op(LSR, ZeroPage, 5),
  0x56: Op(LSR, ZeroPageX, 6),
  0x4e: Op(LSR, Absolute, 6),
  0x5e: Op(LSR, AbsoluteX, 7),

  0x1a: Op(NOP, Implied, 2),
  0x3a: Op(NOP, Implied, 2),
  0x5a: Op(NOP, Implied, 2),
  0x7a: Op(NOP, Implied, 2),
  0xda: Op(NOP, Implied, 2),
  0xea: Op(NOP, Implied, 2),
  0xfa: Op(NOP, Implied, 2),

  0x09: Op(ORA, Immediate, 2),
  0x05: Op(ORA, ZeroPage, 3),
  0x15: Op(ORA, ZeroPageX, 4),
  0x0d: Op(ORA, Absolute, 4),
  0x1d: Op(ORA, AbsoluteX, 4), // cycles +1 if page crossed
  0x19: Op(ORA, AbsoluteY, 4), // cycles +1 if page crossed
  0x01: Op(ORA, IndexedIndirect, 6),
  0x11: Op(ORA, IndirectIndexed, 5), // cycles +1 if page crossed

  0x48: Op(PHA, Implied, 3),

  0x08: Op(PHP, Implied, 3),

  0x68: Op(PLA, Implied, 4),

  0x28: Op(PLP, Implied, 4),

  0x2a: Op(ROL, Accumulator, 2),
  0x26: Op(ROL, ZeroPage, 5),
  0x36: Op(ROL, ZeroPageX, 6),
  0x2e: Op(ROL, Absolute, 6),
  0x3e: Op(ROL, AbsoluteX, 7),

  0x6a: Op(ROR, Accumulator, 2),
  0x66: Op(ROR, ZeroPage, 5),
  0x76: Op(ROR, ZeroPageX, 6),
  0x6e: Op(ROR, Absolute, 6),
  0x7e: Op(ROR, AbsoluteX, 7),

  0x40: Op(RTI, Implied, 6),

  0x60: Op(RTS, Implied, 6),

  0xe9: Op(SBC, Immediate, 2),
  0xe5: Op(SBC, ZeroPage, 3),
  0xf5: Op(SBC, ZeroPageX, 4),
  0xed: Op(SBC, Absolute, 4),
  0xfd: Op(SBC, AbsoluteX, 4), // cycles +1 if page crossed
  0xf9: Op(SBC, AbsoluteY, 4), // cycles +1 if page crossed
  0xe1: Op(SBC, IndexedIndirect, 6),
  0xf1: Op(SBC, IndirectIndexed, 5), // cycles +1 if page crossed

  0x38: Op(SEC, Implied, 2),

  0xf8: Op(SED, Implied, 2),

  0x78: Op(SEI, Implied, 2),

  0x85: Op(STA, ZeroPage, 3),
  0x95: Op(STA, ZeroPageX, 4),
  0x8d: Op(STA, Absolute, 4),
  0x9d: Op(STA, AbsoluteX, 5),
  0x99: Op(STA, AbsoluteY, 5),
  0x81: Op(STA, IndexedIndirect, 6),
  0x91: Op(STA, IndirectIndexed, 6),

  0x86: Op(STX, ZeroPage, 3),
  0x96: Op(STX, ZeroPageY, 4),
  0x8e: Op(STX, Absolute, 4),

  0x84: Op(STY, ZeroPage, 3),
  0x94: Op(STY, ZeroPageX, 4),
  0x8c: Op(STY, Absolute, 4),

  0xaa: Op(TAX, Implied, 2),

  0xa8: Op(TAY, Implied, 2),

  0xba: Op(TSX, Implied, 2),

  0x8a: Op(TXA, Implied, 2),

  0x9a: Op(TXS, Implied, 2),

  0x98: Op(TYA, Implied, 2),

  0x4b: Op(ALR, Immediate, 2),

  0x0b: Op(ANC, Immediate, 2),
  0x2b: Op(ANC, Immediate, 2),

  0x6b: Op(ARR, Immediate, 2),

  0xcb: Op(AXS, Immediate, 2),

  0xa7: Op(LAX, ZeroPage, 3),
  0xb7: Op(LAX, ZeroPageY, 4),
  0xaf: Op(LAX, Absolute, 4),
  0xbf: Op(LAX, AbsoluteY, 4), // cycles +1 if page crossed
  0xa3: Op(LAX, IndexedIndirect, 6),
  0xb3: Op(LAX, IndirectIndexed, 5), // cycles +1 if page crossed

  0x87: Op(SAX, ZeroPage, 3),
  0x97: Op(SAX, ZeroPageY, 4),
  0x8f: Op(SAX, Absolute, 4),
  0x83: Op(SAX, IndexedIndirect, 6), // cycles +1 if page crossed

  0xc7: Op(DCP, ZeroPage, 5),
  0xd7: Op(DCP, ZeroPageX, 6),
  0xcf: Op(DCP, Absolute, 6),
  0xdf: Op(DCP, AbsoluteX, 7), // cycles +1 if page crossed
  0xdb: Op(DCP, AbsoluteY, 7), // cycles +1 if page crossed
  0xc3: Op(DCP, IndexedIndirect, 8),
  0xd3: Op(DCP, IndirectIndexed, 8), // cycles +1 if page crossed

  0xe7: Op(ISC, ZeroPage, 5),
  0xf7: Op(ISC, ZeroPageX, 6),
  0xef: Op(ISC, Absolute, 6),
  0xff: Op(ISC, AbsoluteX, 7), // cycles +1 if page crossed
  0xfb: Op(ISC, AbsoluteY, 7), // cycles +1 if page crossed
  0xe3: Op(ISC, IndexedIndirect, 8),
  0xf3: Op(ISC, IndirectIndexed, 8), // cycles +1 if page crossed

  0x27: Op(RLA, ZeroPage, 5),
  0x37: Op(RLA, ZeroPageX, 6),
  0x2f: Op(RLA, Absolute, 6),
  0x3f: Op(RLA, AbsoluteX, 7), // cycles +1 if page crossed
  0x3b: Op(RLA, AbsoluteY, 7), // cycles +1 if page crossed
  0x23: Op(RLA, IndexedIndirect, 8),
  0x33: Op(RLA, IndirectIndexed, 8), // cycles +1 if page crossed

  0x67: Op(RRA, ZeroPage, 5),
  0x77: Op(RRA, ZeroPageX, 6),
  0x6f: Op(RRA, Absolute, 6),
  0x7f: Op(RRA, AbsoluteX, 7), // cycles +1 if page crossed
  0x7b: Op(RRA, AbsoluteY, 7), // cycles +1 if page crossed
  0x63: Op(RRA, IndexedIndirect, 8),
  0x73: Op(RRA, IndirectIndexed, 8), // cycles +1 if page crossed

  0x07: Op(SLO, ZeroPage, 5),
  0x17: Op(SLO, ZeroPageX, 6),
  0x0f: Op(SLO, Absolute, 6),
  0x1f: Op(SLO, AbsoluteX, 7), // cycles +1 if page crossed
  0x1b: Op(SLO, AbsoluteY, 7), // cycles +1 if page crossed
  0x03: Op(SLO, IndexedIndirect, 8),
  0x13: Op(SLO, IndirectIndexed, 8), // cycles +1 if page crossed

  0x47: Op(SRE, ZeroPage, 5),
  0x57: Op(SRE, ZeroPageX, 6),
  0x4f: Op(SRE, Absolute, 6),
  0x5f: Op(SRE, AbsoluteX, 7), // cycles +1 if page crossed
  0x5b: Op(SRE, AbsoluteY, 7), // cycles +1 if page crossed
  0x43: Op(SRE, IndexedIndirect, 8),
  0x53: Op(SRE, IndirectIndexed, 8), // cycles +1 if page crossed

  0x80: Op(SKB, Immediate, 2),
  0x82: Op(SKB, Immediate, 2),
  0x89: Op(SKB, Immediate, 2),
  0xc2: Op(SKB, Immediate, 2),
  0xe2: Op(SKB, Immediate, 2),

  0x0c: Op(IGN, Absolute, 4),
  0x1c: Op(IGN, AbsoluteX, 4), // cycles +1 if page crossed
  0x3c: Op(IGN, AbsoluteX, 4), // cycles +1 if page crossed
  0x5c: Op(IGN, AbsoluteX, 4), // cycles +1 if page crossed
  0x7c: Op(IGN, AbsoluteX, 4), // cycles +1 if page crossed
  0xdc: Op(IGN, AbsoluteX, 4), // cycles +1 if page crossed
  0xfc: Op(IGN, AbsoluteX, 4), // cycles +1 if page crossed
  0x04: Op(IGN, ZeroPage, 3),
  0x44: Op(IGN, ZeroPage, 3),
  0x64: Op(IGN, ZeroPage, 3),
  0x14: Op(IGN, ZeroPageX, 4),
  0x34: Op(IGN, ZeroPageX, 4),
  0x54: Op(IGN, ZeroPageX, 4),
  0x74: Op(IGN, ZeroPageX, 4),
  0xd4: Op(IGN, ZeroPageX, 4),
  0xf4: Op(IGN, ZeroPageX, 4),
};
