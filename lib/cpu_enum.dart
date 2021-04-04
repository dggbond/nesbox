library flutter_nes;

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
enum InsEnum {
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
  const Op(this.ins, this.addrMode, this.bytes, this.cycles);

  final InsEnum ins;
  final AddrMode addrMode;
  final int bytes;
  final int cycles;
}

const Map<int, Op> opMap = {
  0x69: Op(InsEnum.ADC, AddrMode.Immediate, 2, 2),
  0x65: Op(InsEnum.ADC, AddrMode.ZeroPage, 2, 3),
  0x75: Op(InsEnum.ADC, AddrMode.ZeroPageX, 2, 4),
  0x6d: Op(InsEnum.ADC, AddrMode.Absolute, 3, 4),
  0x7d: Op(InsEnum.ADC, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0x79: Op(InsEnum.ADC, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0x61: Op(InsEnum.ADC, AddrMode.IndirectX, 2, 6),
  0x71: Op(InsEnum.ADC, AddrMode.IndirectY, 2, 5), // cycles +1 if page crossed

  0x29: Op(InsEnum.AND, AddrMode.Immediate, 2, 2),
  0x25: Op(InsEnum.AND, AddrMode.ZeroPage, 2, 3),
  0x35: Op(InsEnum.AND, AddrMode.ZeroPageX, 2, 4),
  0x2d: Op(InsEnum.AND, AddrMode.Absolute, 3, 4),
  0x3d: Op(InsEnum.AND, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0x39: Op(InsEnum.AND, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0x21: Op(InsEnum.AND, AddrMode.IndirectX, 2, 6),
  0x31: Op(InsEnum.AND, AddrMode.IndirectY, 2, 5), // cycles +1 if page crossed

  0x0a: Op(InsEnum.ASL, AddrMode.Immediate, 1, 2),
  0x06: Op(InsEnum.ASL, AddrMode.ZeroPage, 2, 5),
  0x16: Op(InsEnum.ASL, AddrMode.ZeroPageX, 2, 6),
  0x0e: Op(InsEnum.ASL, AddrMode.Absolute, 3, 6),
  0x1e: Op(InsEnum.ASL, AddrMode.AbsoluteX, 3, 7),

  0x90: Op(InsEnum.BCC, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0xb0: Op(InsEnum.BCS, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0xf0: Op(InsEnum.BCS, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x24: Op(InsEnum.BIT, AddrMode.ZeroPage, 2, 3),
  0x2c: Op(InsEnum.BIT, AddrMode.Absolute, 3, 4),

  0x30: Op(InsEnum.BMI, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0xd0: Op(InsEnum.BNE, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x10: Op(InsEnum.BPL, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x00: Op(InsEnum.BRK, AddrMode.Implied, 1, 7),

  0x50: Op(InsEnum.BVC, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x70: Op(InsEnum.BVS, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0x18: Op(InsEnum.CLC, AddrMode.Implied, 1, 2),

  0xd8: Op(InsEnum.CLD, AddrMode.Implied, 1, 2),

  0x58: Op(InsEnum.CLI, AddrMode.Implied, 1, 2),

  0xb8: Op(InsEnum.CLV, AddrMode.Implied, 1, 2),

  0xc9: Op(InsEnum.CMP, AddrMode.Immediate, 2, 2),
  0xc5: Op(InsEnum.CMP, AddrMode.ZeroPage, 2, 3),
  0xd5: Op(InsEnum.CMP, AddrMode.ZeroPageX, 2, 4),
  0xcd: Op(InsEnum.CMP, AddrMode.Absolute, 3, 4),
  0xdd: Op(InsEnum.CMP, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0xd9: Op(InsEnum.CMP, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0xc1: Op(InsEnum.CMP, AddrMode.IndirectX, 2, 6),
  0xd1: Op(InsEnum.CMP, AddrMode.IndirectY, 2, 5), // cycles +1 if page crossed

  0xe0: Op(InsEnum.CPX, AddrMode.Immediate, 2, 2),
  0xe4: Op(InsEnum.CPX, AddrMode.ZeroPage, 2, 3),
  0xec: Op(InsEnum.CPX, AddrMode.Absolute, 3, 4),

  0xc0: Op(InsEnum.CPY, AddrMode.Immediate, 2, 2),
  0xc4: Op(InsEnum.CPY, AddrMode.ZeroPage, 2, 3),
  0xcc: Op(InsEnum.CPY, AddrMode.Absolute, 3, 4),

  0xc6: Op(InsEnum.DEC, AddrMode.ZeroPage, 2, 5),
  0xd6: Op(InsEnum.DEC, AddrMode.ZeroPageX, 2, 6),
  0xce: Op(InsEnum.DEC, AddrMode.Absolute, 3, 6),
  0xde: Op(InsEnum.DEC, AddrMode.AbsoluteX, 3, 7),

  0xca: Op(InsEnum.DEX, AddrMode.Implied, 1, 2),

  0x88: Op(InsEnum.DEY, AddrMode.Implied, 1, 2),

  0x49: Op(InsEnum.EOR, AddrMode.Immediate, 2, 2),
  0x45: Op(InsEnum.EOR, AddrMode.ZeroPage, 2, 3),
  0x55: Op(InsEnum.EOR, AddrMode.ZeroPageX, 2, 4),
  0x4d: Op(InsEnum.EOR, AddrMode.Absolute, 3, 4),
  0x5d: Op(InsEnum.EOR, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0x59: Op(InsEnum.EOR, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0x41: Op(InsEnum.EOR, AddrMode.IndirectX, 2, 6),
  0x51: Op(InsEnum.EOR, AddrMode.IndirectY, 2, 5), // cycles +1 if page crossed

  0xe6: Op(InsEnum.INC, AddrMode.ZeroPage, 2, 5),
  0xf6: Op(InsEnum.INC, AddrMode.ZeroPageX, 2, 6),
  0xee: Op(InsEnum.INC, AddrMode.Absolute, 3, 6),
  0xfe: Op(InsEnum.INC, AddrMode.AbsoluteX, 3, 7),

  0xe8: Op(InsEnum.INX, AddrMode.Implied, 1, 2),

  0xc8: Op(InsEnum.INY, AddrMode.Implied, 1, 2),

  0x4c: Op(InsEnum.JMP, AddrMode.Absolute, 3, 3),
  0x6c: Op(InsEnum.JMP, AddrMode.Indirect, 3, 5),

  0x20: Op(InsEnum.JSR, AddrMode.Absolute, 3, 6),

  0xa9: Op(InsEnum.LDA, AddrMode.Immediate, 2, 2),
  0xa5: Op(InsEnum.LDA, AddrMode.ZeroPage, 2, 3),
  0xb5: Op(InsEnum.LDA, AddrMode.ZeroPageX, 2, 4),
  0xad: Op(InsEnum.LDA, AddrMode.Absolute, 3, 4),
  0xbd: Op(InsEnum.LDA, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0xb9: Op(InsEnum.LDA, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0xa1: Op(InsEnum.LDA, AddrMode.IndirectX, 2, 6),
  0xb1: Op(InsEnum.LDA, AddrMode.IndirectY, 2, 5), // cycles +1 if page crossed

  0xa2: Op(InsEnum.LDX, AddrMode.Immediate, 2, 2),
  0xa6: Op(InsEnum.LDX, AddrMode.ZeroPage, 2, 3),
  0xb6: Op(InsEnum.LDX, AddrMode.ZeroPageY, 2, 4),
  0xae: Op(InsEnum.LDX, AddrMode.Absolute, 3, 4),
  0xbe: Op(InsEnum.LDX, AddrMode.AbsoluteY, 3, 4), // cycles + 1 if page crossed

  0xa0: Op(InsEnum.LDY, AddrMode.Immediate, 2, 2),
  0xa4: Op(InsEnum.LDY, AddrMode.ZeroPage, 2, 3),
  0xb4: Op(InsEnum.LDY, AddrMode.ZeroPageY, 2, 4),
  0xac: Op(InsEnum.LDY, AddrMode.Absolute, 3, 4),
  0xbc: Op(InsEnum.LDY, AddrMode.AbsoluteY, 3, 4), // cycles + 1 if page crossed

  0x4a: Op(InsEnum.LSR, AddrMode.Immediate, 1, 2),
  0x46: Op(InsEnum.LSR, AddrMode.ZeroPage, 2, 5),
  0x56: Op(InsEnum.LSR, AddrMode.ZeroPageX, 2, 6),
  0x4e: Op(InsEnum.LSR, AddrMode.Absolute, 3, 6),
  0x5e: Op(InsEnum.LSR, AddrMode.AbsoluteX, 3, 7),

  0xea: Op(InsEnum.NOP, AddrMode.Implied, 1, 2),

  0x09: Op(InsEnum.ORA, AddrMode.Immediate, 2, 2),
  0x05: Op(InsEnum.ORA, AddrMode.ZeroPage, 2, 3),
  0x15: Op(InsEnum.ORA, AddrMode.ZeroPageX, 2, 4),
  0x0d: Op(InsEnum.ORA, AddrMode.Absolute, 3, 4),
  0x1d: Op(InsEnum.ORA, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0x19: Op(InsEnum.ORA, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0x01: Op(InsEnum.ORA, AddrMode.IndirectX, 2, 6),
  0x11: Op(InsEnum.ORA, AddrMode.IndirectY, 2, 5), // cycles +1 if page crossed

  0x48: Op(InsEnum.PHA, AddrMode.Implied, 1, 3),

  0x08: Op(InsEnum.PHP, AddrMode.Implied, 1, 3),

  0x68: Op(InsEnum.PLA, AddrMode.Implied, 1, 4),

  0x28: Op(InsEnum.PLP, AddrMode.Implied, 1, 4),

  0x2a: Op(InsEnum.ROL, AddrMode.Immediate, 1, 2),
  0x26: Op(InsEnum.ROL, AddrMode.ZeroPage, 2, 5),
  0x36: Op(InsEnum.ROL, AddrMode.ZeroPageX, 2, 6),
  0x2e: Op(InsEnum.ROL, AddrMode.Absolute, 3, 6),
  0x3e: Op(InsEnum.ROL, AddrMode.AbsoluteX, 3, 7),

  0x6a: Op(InsEnum.ROR, AddrMode.Immediate, 1, 2),
  0x66: Op(InsEnum.ROR, AddrMode.ZeroPage, 2, 5),
  0x76: Op(InsEnum.ROR, AddrMode.ZeroPageX, 2, 6),
  0x6e: Op(InsEnum.ROR, AddrMode.Absolute, 3, 6),
  0x7e: Op(InsEnum.ROR, AddrMode.AbsoluteX, 3, 7),

  0x40: Op(InsEnum.RTI, AddrMode.Implied, 1, 6),

  0x60: Op(InsEnum.RTS, AddrMode.Implied, 1, 6),

  0xe9: Op(InsEnum.SBC, AddrMode.Immediate, 2, 2),
  0xe5: Op(InsEnum.SBC, AddrMode.ZeroPage, 2, 3),
  0xf5: Op(InsEnum.SBC, AddrMode.ZeroPageX, 2, 4),
  0xed: Op(InsEnum.SBC, AddrMode.Absolute, 3, 4),
  0xfd: Op(InsEnum.SBC, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0xf9: Op(InsEnum.SBC, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0xe1: Op(InsEnum.SBC, AddrMode.IndirectX, 2, 6),
  0xf1: Op(InsEnum.SBC, AddrMode.IndirectY, 2, 5), // cycles +1 if page crossed

  0x38: Op(InsEnum.SEC, AddrMode.Implied, 1, 2),

  0xf8: Op(InsEnum.SED, AddrMode.Implied, 1, 2),

  0x78: Op(InsEnum.SEI, AddrMode.Implied, 1, 2),

  0x85: Op(InsEnum.STA, AddrMode.ZeroPage, 2, 3),
  0x95: Op(InsEnum.STA, AddrMode.ZeroPageX, 2, 4),
  0x8d: Op(InsEnum.STA, AddrMode.Absolute, 3, 4),
  0x9d: Op(InsEnum.STA, AddrMode.AbsoluteX, 3, 5),
  0x99: Op(InsEnum.STA, AddrMode.AbsoluteY, 3, 5),
  0x81: Op(InsEnum.STA, AddrMode.IndirectX, 2, 6),
  0x91: Op(InsEnum.STA, AddrMode.IndirectY, 2, 6),

  0x86: Op(InsEnum.STX, AddrMode.ZeroPage, 2, 3),
  0x96: Op(InsEnum.STX, AddrMode.ZeroPageY, 2, 4),
  0x8e: Op(InsEnum.STX, AddrMode.Absolute, 3, 4),

  0x84: Op(InsEnum.STY, AddrMode.ZeroPage, 2, 3),
  0x94: Op(InsEnum.STY, AddrMode.ZeroPageX, 2, 4),
  0x8c: Op(InsEnum.STY, AddrMode.Absolute, 3, 4),

  0xaa: Op(InsEnum.TAX, AddrMode.Implied, 1, 2),

  0xa8: Op(InsEnum.TAY, AddrMode.Implied, 1, 2),

  0xba: Op(InsEnum.TSX, AddrMode.Implied, 1, 2),

  0x8a: Op(InsEnum.TXA, AddrMode.Implied, 1, 2),

  0x9a: Op(InsEnum.TXS, AddrMode.Implied, 1, 2),

  0x98: Op(InsEnum.TYA, AddrMode.Implied, 1, 2),
};
