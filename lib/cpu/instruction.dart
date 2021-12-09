library flutter_nes.cpu;

import 'cpu.dart';
import 'address_mode.dart';
import 'package:flutter_nes/util/util.dart';

typedef void Instuction(CPU cpu);

branchSuccess(CPU cpu) {
  cpu.cycles += isPageCrossed(cpu.address, cpu.regPC) ? 2 : 1;

  cpu.regPC = cpu.address;
}

ADC(CPU cpu) {
  int fetched = cpu.fetch();
  int tmp = cpu.regA + fetched + cpu.fCarry;

  // overflow is basically negative + negative = positive
  // postive + positive = negative
  bool overflow = (tmp ^ cpu.regA) & 0x80 != 0 && (tmp ^ fetched) & 0x80 != 0;

  cpu.fCarry = tmp > 0xff ? 1 : 0;
  cpu.fOverflow = overflow ? 1 : 0;
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
  cpu.fCarry = fetched.getBit(7);

  fetched = (fetched << 1) & 0xff;

  if (cpu.op.mode == Accumulator) {
    cpu.regA = fetched;
  } else {
    cpu.write(cpu.address, fetched);
  }

  cpu.fZero = fetched.getZeroBit();
  cpu.fNegative = fetched.getBit(7);
}

BIT(CPU cpu) {
  int fetched = cpu.fetch();
  int test = fetched & cpu.regA;

  cpu.fZero = test.getZeroBit();
  cpu.fOverflow = fetched.getBit(6);
  cpu.fNegative = fetched.getBit(7);
}

BCC(CPU cpu) {
  if (cpu.fCarry == 0) branchSuccess(cpu);
}

BCS(CPU cpu) {
  if (cpu.fCarry == 1) branchSuccess(cpu);
}

BEQ(CPU cpu) {
  if (cpu.fZero == 1) branchSuccess(cpu);
}

BMI(CPU cpu) {
  if (cpu.fNegative == 1) branchSuccess(cpu);
}

BNE(CPU cpu) {
  if (cpu.fZero == 0) branchSuccess(cpu);
}

BPL(CPU cpu) {
  if (cpu.fNegative == 0) branchSuccess(cpu);
}

BVC(CPU cpu) {
  if (cpu.fOverflow == 0) branchSuccess(cpu);
}

BVS(CPU cpu) {
  if (cpu.fOverflow == 1) branchSuccess(cpu);
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
  fetched &= 0xff;
  cpu.write(cpu.address, fetched & 0xff);

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
  fetched &= 0xff;

  cpu.write(cpu.address, fetched & 0xff);

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

JMP(CPU cpu) => cpu.regPC = cpu.address;
JSR(CPU cpu) {
  cpu.pushStack16Bit(cpu.regPC - 1);
  cpu.regPC = cpu.address;
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
  cpu.fCarry = fetched.getBit(0);
  fetched = (fetched >> 1) & 0xff;

  if (cpu.op.mode == Accumulator) {
    cpu.regA = fetched;
  } else {
    cpu.write(cpu.address, fetched);
  }

  cpu.fZero = fetched.getZeroBit();
  cpu.fNegative = 0;
}

ORA(CPU cpu) {
  int fetched = cpu.fetch();
  cpu.regA |= fetched;

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
  int fetched = cpu.fetch();
  int oldCarry = cpu.fCarry;

  cpu.fCarry = fetched.getBit(7);
  fetched = (fetched << 1).setBit(0, oldCarry);

  if (cpu.op.mode == Accumulator) {
    cpu.regA = fetched & 0xff;
    cpu.fZero = cpu.regA.getZeroBit();
  } else {
    cpu.write(cpu.address, fetched);
  }

  cpu.fNegative = fetched.getBit(7);
}

ROR(CPU cpu) {
  int fetched = cpu.fetch();
  int oldCarry = cpu.fCarry;

  cpu.fCarry = fetched.getBit(0);
  fetched = (fetched >> 1).setBit(7, oldCarry);

  if (cpu.op.mode == Accumulator) {
    cpu.regA = fetched;
    cpu.fZero = cpu.regA.getZeroBit();
  } else {
    cpu.write(cpu.address, fetched);
  }

  cpu.fNegative = fetched.getBit(7);
}

RTI(CPU cpu) {
  int value = cpu.popStack().setBit(4, cpu.fBreakCommand).setBit(5, cpu.fUnused);
  cpu.regPS = value;
  cpu.regPC = cpu.popStack16Bit();
}

RTS(CPU cpu) => cpu.regPC = cpu.popStack16Bit() + 1;
SBC(CPU cpu) {
  int fetched = cpu.fetch();
  int tmp = cpu.regA - fetched - (1 - cpu.fCarry);

  bool overflow = (tmp ^ cpu.regA) & 0x80 != 0 && (cpu.regA ^ fetched) & 0x80 != 0;

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

// NOPs
NOP(CPU cpu) {}
SKB(CPU cpu) {}
IGN(CPU cpu) {}
