library cpu;

import "dart:convert";

// http://nesdev.com/NESDoc.pdf, see Appendix E Addressing Mode
enum AddrMode {
  // at page 39
  ZeroPage,
  ZeroPageX,
  ZeroPageY,

  // at page 40
  Absolute,

  // at page 41
  AbsoluteX,
  AbsoluteY,
  Indirect,

  // at page 42
  Implied,
  Accumulator,
  Immediate,

  // at page 43
  Relative,
  IndirectX,
  IndirectY,
  IndirectIndexed,
}

// instruction enum
enum Instr {
  ADC, // Add with Carry
  AND, // Logical AND
  ASL, // Arithmetic Shift Left
  BCC, // Branch if Carry Clear
  BCS, // Branch if Carry Set
  BEQ, // Branch if Equal
  BIT, // Bit Test
  BMI, // Branch if Minus
  BNE, // Branch if Not Equal
  BPL, // Branch if Positive
  BRK, // Force Interrupt
  BVC, // Branch if Overflow Clear
  BVS, // Branch if Overflow Set
  CLC, // Clear Carry Flag
  CLD, // Clear Decimal Mode
  CLI, // Clear Interrupt Disable
  CLV, // Clear Overflow Flag
  CMP, // Compare
  CPX, // Compare X Register
  CPY, // Compare Y Register
  DEC, // Decrement Memory
  DEX, // Decrement X Register
  DEY, // Decrement Y Register
  EOR, // Exclusive OR
  INC, // Increment Memory
  INX, // Increment X Register
  INY, // Increment Y Register
  JMP, // Jump
  JSR, // Jump to Subroutine
  LDA, // Load Accumulator
  LDX, // Load X Register
  LDY, // Load Y Register
  LSR, // Logical Shift Right
  NOP, // No Operation
  ORA, // Logical Inclusive OR
  PHA, // Push Accumulator
  PHP, // Push Processor Status
  PLA, // Pull Accumulator
  PLP, // Pull Processor Status
  ROL, // Rotate Left
  ROR, // Rotate Right
  RTI, // Return from Interrupt
  RTS, // Return from Subroutine
  SBC, // Subtract with Carry
  SEC, // Set Carry Flag
  SED, // Set Decimal Flag
  SEI, // Set Interrupt Disable
  STA, // Store Accumulator
  STX, // Store X Register
  STY, // Store Y Register
  TAX, // Transfer Accumulator to X
  TAY, // Transfer Accumulator to Y
  TSX, // Transfer Stack Pointer to X
  TXA, // Transfer X to Accumulator
  TXS, // Transfer X to Stack Pointer
  TYA, // Transfer Y to Accumulator
}

class Op {
  const Op(this.instr, this.addrMode, this.bytes, this.cycles);

  final Instr instr;
  final AddrMode addrMode;
  final int bytes;
  final int cycles;

  toJSON() {
    var encoder = new JsonEncoder.withIndent("  ");

    return "op: " +
        encoder.convert({
          "instr   ": instr.toString(),
          "addrMode": addrMode.toString(),
          "bytes   ": bytes,
          "cycles  ": cycles,
        });
  }
}

const Map<int, Op> _OP_MAP = {
  0x69: Op(Instr.ADC, AddrMode.Immediate, 2, 2),
  0x65: Op(Instr.ADC, AddrMode.ZeroPage, 2, 3),
  0x75: Op(Instr.ADC, AddrMode.ZeroPageX, 2, 4),
  0x6d: Op(Instr.ADC, AddrMode.Absolute, 3, 4),
  0x7d: Op(Instr.ADC, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0x79: Op(Instr.ADC, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0x61: Op(Instr.ADC, AddrMode.IndirectX, 2, 6),
  0x71: Op(Instr.ADC, AddrMode.IndirectY, 2, 5), // cycles +1 if page crossed

  0x29: Op(Instr.AND, AddrMode.Immediate, 2, 2),
  0x25: Op(Instr.AND, AddrMode.ZeroPage, 2, 3),
  0x35: Op(Instr.AND, AddrMode.ZeroPageX, 2, 4),
  0x2d: Op(Instr.AND, AddrMode.Absolute, 3, 4),
  0x3d: Op(Instr.AND, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0x39: Op(Instr.AND, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0x21: Op(Instr.AND, AddrMode.IndirectX, 2, 6),
  0x31: Op(Instr.AND, AddrMode.IndirectY, 2, 5), // cycles +1 if page crossed

  0x0a: Op(Instr.ASL, AddrMode.Immediate, 1, 2),
  0x06: Op(Instr.ASL, AddrMode.ZeroPage, 2, 5),
  0x16: Op(Instr.ASL, AddrMode.ZeroPageX, 2, 6),
  0x0e: Op(Instr.ASL, AddrMode.Absolute, 3, 6),
  0x1e: Op(Instr.ASL, AddrMode.AbsoluteX, 3, 7),

  0x90: Op(Instr.BCC, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0xb0: Op(Instr.BCS, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0xf0: Op(Instr.BCS, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x24: Op(Instr.BIT, AddrMode.ZeroPage, 2, 3),
  0x2c: Op(Instr.BIT, AddrMode.Absolute, 3, 4),

  0x30: Op(Instr.BMI, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0xd0: Op(Instr.BNE, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x10: Op(Instr.BPL, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x00: Op(Instr.BRK, AddrMode.Implied, 1, 7),

  0x50: Op(Instr.BVC, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x70: Op(Instr.BVS, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x18: Op(Instr.CLC, AddrMode.Implied, 1, 2),

  0xd8: Op(Instr.CLD, AddrMode.Implied, 1, 2),

  0x58: Op(Instr.CLI, AddrMode.Implied, 1, 2),

  0xb8: Op(Instr.CLV, AddrMode.Implied, 1, 2),

  0xc9: Op(Instr.CMP, AddrMode.Immediate, 2, 2),
  0xc5: Op(Instr.CMP, AddrMode.ZeroPage, 2, 3),
  0xd5: Op(Instr.CMP, AddrMode.ZeroPageX, 2, 4),
  0xcd: Op(Instr.CMP, AddrMode.Absolute, 3, 4),
  0xdd: Op(Instr.CMP, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0xd9: Op(Instr.CMP, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0xc1: Op(Instr.CMP, AddrMode.IndirectX, 2, 6),
  0xd1: Op(Instr.CMP, AddrMode.IndirectY, 2, 5), // cycles +1 if page crossed

  0xe0: Op(Instr.CPX, AddrMode.Immediate, 2, 2),
  0xe4: Op(Instr.CPX, AddrMode.ZeroPage, 2, 3),
  0xec: Op(Instr.CPX, AddrMode.Absolute, 3, 4),

  0xc0: Op(Instr.CPY, AddrMode.Immediate, 2, 2),
  0xc4: Op(Instr.CPY, AddrMode.ZeroPage, 2, 3),
  0xcc: Op(Instr.CPY, AddrMode.Absolute, 3, 4),

  0xc6: Op(Instr.DEC, AddrMode.ZeroPage, 2, 5),
  0xd6: Op(Instr.DEC, AddrMode.ZeroPageX, 2, 6),
  0xce: Op(Instr.DEC, AddrMode.Absolute, 3, 6),
  0xde: Op(Instr.DEC, AddrMode.AbsoluteX, 3, 7),

  0xca: Op(Instr.DEX, AddrMode.Implied, 1, 2),

  0x88: Op(Instr.DEY, AddrMode.Implied, 1, 2),

  0x49: Op(Instr.EOR, AddrMode.Immediate, 2, 2),
  0x45: Op(Instr.EOR, AddrMode.ZeroPage, 2, 3),
  0x55: Op(Instr.EOR, AddrMode.ZeroPageX, 2, 4),
  0x4d: Op(Instr.EOR, AddrMode.Absolute, 3, 4),
  0x5d: Op(Instr.EOR, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0x59: Op(Instr.EOR, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0x41: Op(Instr.EOR, AddrMode.IndirectX, 2, 6),
  0x51: Op(Instr.EOR, AddrMode.IndirectY, 2, 5), // cycles +1 if page crossed

  0xe6: Op(Instr.INC, AddrMode.ZeroPage, 2, 5),
  0xf6: Op(Instr.INC, AddrMode.ZeroPageX, 2, 6),
  0xee: Op(Instr.INC, AddrMode.Absolute, 3, 6),
  0xfe: Op(Instr.INC, AddrMode.AbsoluteX, 3, 7),

  0xe8: Op(Instr.INX, AddrMode.Implied, 1, 2),

  0xc8: Op(Instr.INY, AddrMode.Implied, 1, 2),

  0x4c: Op(Instr.JMP, AddrMode.Absolute, 3, 3),
  0x6c: Op(Instr.JMP, AddrMode.Indirect, 3, 5),

  0x20: Op(Instr.JSR, AddrMode.Absolute, 3, 6),

  0xa9: Op(Instr.LDA, AddrMode.Immediate, 2, 2),
  0xa5: Op(Instr.LDA, AddrMode.ZeroPage, 2, 3),
  0xb5: Op(Instr.LDA, AddrMode.ZeroPageX, 2, 4),
  0xad: Op(Instr.LDA, AddrMode.Absolute, 3, 4),
  0xbd: Op(Instr.LDA, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0xb9: Op(Instr.LDA, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0xa1: Op(Instr.LDA, AddrMode.IndirectX, 2, 6),
  0xb1: Op(Instr.LDA, AddrMode.IndirectY, 2, 5), // cycles +1 if page crossed

  0xa2: Op(Instr.LDX, AddrMode.Immediate, 2, 2),
  0xa6: Op(Instr.LDX, AddrMode.ZeroPage, 2, 3),
  0xb6: Op(Instr.LDX, AddrMode.ZeroPageY, 2, 4),
  0xae: Op(Instr.LDX, AddrMode.Absolute, 3, 4),
  0xbe: Op(Instr.LDX, AddrMode.AbsoluteY, 3, 4), // cycles + 1 if page crossed

  0xa0: Op(Instr.LDY, AddrMode.Immediate, 2, 2),
  0xa4: Op(Instr.LDY, AddrMode.ZeroPage, 2, 3),
  0xb4: Op(Instr.LDY, AddrMode.ZeroPageY, 2, 4),
  0xac: Op(Instr.LDY, AddrMode.Absolute, 3, 4),
  0xbc: Op(Instr.LDY, AddrMode.AbsoluteY, 3, 4), // cycles + 1 if page crossed

  0x4a: Op(Instr.LSR, AddrMode.Immediate, 1, 2),
  0x46: Op(Instr.LSR, AddrMode.ZeroPage, 2, 5),
  0x56: Op(Instr.LSR, AddrMode.ZeroPageX, 2, 6),
  0x4e: Op(Instr.LSR, AddrMode.Absolute, 3, 6),
  0x5e: Op(Instr.LSR, AddrMode.AbsoluteX, 3, 7),

  0xea: Op(Instr.NOP, AddrMode.Implied, 1, 2),

  0x09: Op(Instr.ORA, AddrMode.Immediate, 2, 2),
  0x05: Op(Instr.ORA, AddrMode.ZeroPage, 2, 3),
  0x15: Op(Instr.ORA, AddrMode.ZeroPageX, 2, 4),
  0x0d: Op(Instr.ORA, AddrMode.Absolute, 3, 4),
  0x1d: Op(Instr.ORA, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0x19: Op(Instr.ORA, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0x01: Op(Instr.ORA, AddrMode.IndirectX, 2, 6),
  0x11: Op(Instr.ORA, AddrMode.IndirectY, 2, 5), // cycles +1 if page crossed

  0x48: Op(Instr.PHA, AddrMode.Implied, 1, 3),

  0x08: Op(Instr.PHP, AddrMode.Implied, 1, 3),

  0x68: Op(Instr.PLA, AddrMode.Implied, 1, 4),

  0x28: Op(Instr.PLP, AddrMode.Implied, 1, 4),

  0x2a: Op(Instr.ROL, AddrMode.Immediate, 1, 2),
  0x26: Op(Instr.ROL, AddrMode.ZeroPage, 2, 5),
  0x36: Op(Instr.ROL, AddrMode.ZeroPageX, 2, 6),
  0x2e: Op(Instr.ROL, AddrMode.Absolute, 3, 6),
  0x3e: Op(Instr.ROL, AddrMode.AbsoluteX, 3, 7),

  0x6a: Op(Instr.ROR, AddrMode.Immediate, 1, 2),
  0x66: Op(Instr.ROR, AddrMode.ZeroPage, 2, 5),
  0x76: Op(Instr.ROR, AddrMode.ZeroPageX, 2, 6),
  0x6e: Op(Instr.ROR, AddrMode.Absolute, 3, 6),
  0x7e: Op(Instr.ROR, AddrMode.AbsoluteX, 3, 7),

  0x40: Op(Instr.RTI, AddrMode.Implied, 1, 6),

  0x60: Op(Instr.RTS, AddrMode.Implied, 1, 6),

  0xe9: Op(Instr.SBC, AddrMode.Immediate, 2, 2),
  0xe5: Op(Instr.SBC, AddrMode.ZeroPage, 2, 3),
  0xf5: Op(Instr.SBC, AddrMode.ZeroPageX, 2, 4),
  0xed: Op(Instr.SBC, AddrMode.Absolute, 3, 4),
  0xfd: Op(Instr.SBC, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0xf9: Op(Instr.SBC, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0xe1: Op(Instr.SBC, AddrMode.IndirectX, 2, 6),
  0xf1: Op(Instr.SBC, AddrMode.IndirectY, 2, 5), // cycles +1 if page crossed

  0x38: Op(Instr.SEC, AddrMode.Implied, 1, 2),

  0xf8: Op(Instr.SED, AddrMode.Implied, 1, 2),

  0x78: Op(Instr.SEI, AddrMode.Implied, 1, 2),

  0x85: Op(Instr.STA, AddrMode.ZeroPage, 2, 3),
  0x95: Op(Instr.STA, AddrMode.ZeroPageX, 2, 4),
  0x8d: Op(Instr.STA, AddrMode.Absolute, 3, 4),
  0x9d: Op(Instr.STA, AddrMode.AbsoluteX, 3, 5),
  0x99: Op(Instr.STA, AddrMode.AbsoluteY, 3, 5),
  0x81: Op(Instr.STA, AddrMode.IndirectX, 2, 6),
  0x91: Op(Instr.STA, AddrMode.IndirectY, 2, 6),

  0x86: Op(Instr.STX, AddrMode.ZeroPage, 2, 3),
  0x96: Op(Instr.STX, AddrMode.ZeroPageY, 2, 4),
  0x8e: Op(Instr.STX, AddrMode.Absolute, 3, 4),

  0x84: Op(Instr.STY, AddrMode.ZeroPage, 2, 3),
  0x94: Op(Instr.STY, AddrMode.ZeroPageX, 2, 4),
  0x8c: Op(Instr.STY, AddrMode.Absolute, 3, 4),

  0xaa: Op(Instr.TAX, AddrMode.Implied, 1, 2),

  0xa8: Op(Instr.TAY, AddrMode.Implied, 1, 2),

  0xba: Op(Instr.TSX, AddrMode.Implied, 1, 2),

  0x8a: Op(Instr.TXA, AddrMode.Implied, 1, 2),

  0x9a: Op(Instr.TXS, AddrMode.Implied, 1, 2),

  0x98: Op(Instr.TYA, AddrMode.Implied, 1, 2),
};

Op findOp(int opcode) {
  return _OP_MAP[opcode];
}