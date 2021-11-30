// see: https://wiki.nesdev.com/w/index.php/CPU_addressing_modes
enum AddrMode {
  // the comment is the abbr.
  // at page 39
  ZeroPage, // d
  ZeroPageX, // d,x
  ZeroPageY, // d,y

  // at page 40
  Absolute, // a

  // at page 41
  AbsoluteX, // a,x
  AbsoluteY, // a,y
  Indirect, // (a)

  // at page 42
  Implied, // no short cut
  Accumulator, // A
  Immediate, // #v or #i

  // at page 43
  Relative, // label
  IndexedIndirect, // (d,x)
  IndirectIndexed, // (d),y
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

  // unofficial Op, see: https://wiki.nesdev.com/w/index.php/Programming_with_unofficial_opcodes
  // Combined operations
  ALR, // call 'ASR' too.
  ANC,
  ARR,
  AXS,
  LAX,
  SAX,

  // RMW(read-modify-write) instructions
  DCP,
  ISC,
  RLA,
  RRA,
  SLO,
  SRE,

  // NOPs
  SKB,
  IGN,
}

enum Interrupt {
  IRQ,
  NMI,
  RESET,
}

class Op {
  const Op(this.instr, this.addrMode, this.bytes, this.cycles);

  final Instr instr;
  final AddrMode addrMode;
  final int bytes;
  final int cycles;

  String get name {
    return "${instr.toString().split(".")[1]}(${addrMode.toString().split(".")[1]})";
  }
}

const Map<int, Op> NES_CPU_OPS = {
  0x69: Op(Instr.ADC, AddrMode.Immediate, 2, 2),
  0x65: Op(Instr.ADC, AddrMode.ZeroPage, 2, 3),
  0x75: Op(Instr.ADC, AddrMode.ZeroPageX, 2, 4),
  0x6d: Op(Instr.ADC, AddrMode.Absolute, 3, 4),
  0x7d: Op(Instr.ADC, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0x79: Op(Instr.ADC, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0x61: Op(Instr.ADC, AddrMode.IndexedIndirect, 2, 6),
  0x71: Op(Instr.ADC, AddrMode.IndirectIndexed, 2, 5), // cycles +1 if page crossed

  0x29: Op(Instr.AND, AddrMode.Immediate, 2, 2),
  0x25: Op(Instr.AND, AddrMode.ZeroPage, 2, 3),
  0x35: Op(Instr.AND, AddrMode.ZeroPageX, 2, 4),
  0x2d: Op(Instr.AND, AddrMode.Absolute, 3, 4),
  0x3d: Op(Instr.AND, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0x39: Op(Instr.AND, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0x21: Op(Instr.AND, AddrMode.IndexedIndirect, 2, 6),
  0x31: Op(Instr.AND, AddrMode.IndirectIndexed, 2, 5), // cycles +1 if page crossed

  0x0a: Op(Instr.ASL, AddrMode.Accumulator, 1, 2),
  0x06: Op(Instr.ASL, AddrMode.ZeroPage, 2, 5),
  0x16: Op(Instr.ASL, AddrMode.ZeroPageX, 2, 6),
  0x0e: Op(Instr.ASL, AddrMode.Absolute, 3, 6),
  0x1e: Op(Instr.ASL, AddrMode.AbsoluteX, 3, 7),

  0x90: Op(Instr.BCC, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0xb0: Op(Instr.BCS, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

  0xf0: Op(Instr.BEQ, AddrMode.Relative, 2, 2), // cycles +1 if branch succeeds +2 if to a new page

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
  0xc1: Op(Instr.CMP, AddrMode.IndexedIndirect, 2, 6),
  0xd1: Op(Instr.CMP, AddrMode.IndirectIndexed, 2, 5), // cycles +1 if page crossed

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
  0x41: Op(Instr.EOR, AddrMode.IndexedIndirect, 2, 6),
  0x51: Op(Instr.EOR, AddrMode.IndirectIndexed, 2, 5), // cycles +1 if page crossed

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
  0xa1: Op(Instr.LDA, AddrMode.IndexedIndirect, 2, 6),
  0xb1: Op(Instr.LDA, AddrMode.IndirectIndexed, 2, 5), // cycles +1 if page crossed

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

  0x4a: Op(Instr.LSR, AddrMode.Accumulator, 1, 2),
  0x46: Op(Instr.LSR, AddrMode.ZeroPage, 2, 5),
  0x56: Op(Instr.LSR, AddrMode.ZeroPageX, 2, 6),
  0x4e: Op(Instr.LSR, AddrMode.Absolute, 3, 6),
  0x5e: Op(Instr.LSR, AddrMode.AbsoluteX, 3, 7),

  0x1a: Op(Instr.NOP, AddrMode.Implied, 1, 2),
  0x3a: Op(Instr.NOP, AddrMode.Implied, 1, 2),
  0x5a: Op(Instr.NOP, AddrMode.Implied, 1, 2),
  0x7a: Op(Instr.NOP, AddrMode.Implied, 1, 2),
  0xda: Op(Instr.NOP, AddrMode.Implied, 1, 2),
  0xea: Op(Instr.NOP, AddrMode.Implied, 1, 2),
  0xfa: Op(Instr.NOP, AddrMode.Implied, 1, 2),

  0x09: Op(Instr.ORA, AddrMode.Immediate, 2, 2),
  0x05: Op(Instr.ORA, AddrMode.ZeroPage, 2, 3),
  0x15: Op(Instr.ORA, AddrMode.ZeroPageX, 2, 4),
  0x0d: Op(Instr.ORA, AddrMode.Absolute, 3, 4),
  0x1d: Op(Instr.ORA, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0x19: Op(Instr.ORA, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0x01: Op(Instr.ORA, AddrMode.IndexedIndirect, 2, 6),
  0x11: Op(Instr.ORA, AddrMode.IndirectIndexed, 2, 5), // cycles +1 if page crossed

  0x48: Op(Instr.PHA, AddrMode.Implied, 1, 3),

  0x08: Op(Instr.PHP, AddrMode.Implied, 1, 3),

  0x68: Op(Instr.PLA, AddrMode.Implied, 1, 4),

  0x28: Op(Instr.PLP, AddrMode.Implied, 1, 4),

  0x2a: Op(Instr.ROL, AddrMode.Accumulator, 1, 2),
  0x26: Op(Instr.ROL, AddrMode.ZeroPage, 2, 5),
  0x36: Op(Instr.ROL, AddrMode.ZeroPageX, 2, 6),
  0x2e: Op(Instr.ROL, AddrMode.Absolute, 3, 6),
  0x3e: Op(Instr.ROL, AddrMode.AbsoluteX, 3, 7),

  0x6a: Op(Instr.ROR, AddrMode.Accumulator, 1, 2),
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
  0xe1: Op(Instr.SBC, AddrMode.IndexedIndirect, 2, 6),
  0xf1: Op(Instr.SBC, AddrMode.IndirectIndexed, 2, 5), // cycles +1 if page crossed

  0x38: Op(Instr.SEC, AddrMode.Implied, 1, 2),

  0xf8: Op(Instr.SED, AddrMode.Implied, 1, 2),

  0x78: Op(Instr.SEI, AddrMode.Implied, 1, 2),

  0x85: Op(Instr.STA, AddrMode.ZeroPage, 2, 3),
  0x95: Op(Instr.STA, AddrMode.ZeroPageX, 2, 4),
  0x8d: Op(Instr.STA, AddrMode.Absolute, 3, 4),
  0x9d: Op(Instr.STA, AddrMode.AbsoluteX, 3, 5),
  0x99: Op(Instr.STA, AddrMode.AbsoluteY, 3, 5),
  0x81: Op(Instr.STA, AddrMode.IndexedIndirect, 2, 6),
  0x91: Op(Instr.STA, AddrMode.IndirectIndexed, 2, 6),

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

  0x4b: Op(Instr.ALR, AddrMode.Immediate, 2, 2),

  0x0b: Op(Instr.ANC, AddrMode.Immediate, 2, 2),
  0x2b: Op(Instr.ANC, AddrMode.Immediate, 2, 2),

  0x6b: Op(Instr.ARR, AddrMode.Immediate, 2, 2),

  0xcb: Op(Instr.AXS, AddrMode.Immediate, 2, 2),

  0xa7: Op(Instr.LAX, AddrMode.ZeroPage, 2, 3),
  0xb7: Op(Instr.LAX, AddrMode.ZeroPageY, 2, 4),
  0xaf: Op(Instr.LAX, AddrMode.Absolute, 3, 4),
  0xbf: Op(Instr.LAX, AddrMode.AbsoluteY, 3, 4), // cycles +1 if page crossed
  0xa3: Op(Instr.LAX, AddrMode.IndexedIndirect, 2, 6),
  0xb3: Op(Instr.LAX, AddrMode.IndirectIndexed, 2, 5), // cycles +1 if page crossed

  0x87: Op(Instr.SAX, AddrMode.ZeroPage, 2, 3),
  0x97: Op(Instr.SAX, AddrMode.ZeroPageY, 2, 4),
  0x8f: Op(Instr.SAX, AddrMode.Absolute, 3, 4),
  0x83: Op(Instr.SAX, AddrMode.IndexedIndirect, 2, 6), // cycles +1 if page crossed

  0xc7: Op(Instr.DCP, AddrMode.ZeroPage, 2, 5),
  0xd7: Op(Instr.DCP, AddrMode.ZeroPageX, 2, 6),
  0xcf: Op(Instr.DCP, AddrMode.Absolute, 3, 6),
  0xdf: Op(Instr.DCP, AddrMode.AbsoluteX, 3, 7), // cycles +1 if page crossed
  0xdb: Op(Instr.DCP, AddrMode.AbsoluteY, 3, 7), // cycles +1 if page crossed
  0xc3: Op(Instr.DCP, AddrMode.IndexedIndirect, 2, 8),
  0xd3: Op(Instr.DCP, AddrMode.IndirectIndexed, 2, 8), // cycles +1 if page crossed

  0xe7: Op(Instr.ISC, AddrMode.ZeroPage, 2, 5),
  0xf7: Op(Instr.ISC, AddrMode.ZeroPageX, 2, 6),
  0xef: Op(Instr.ISC, AddrMode.Absolute, 3, 6),
  0xff: Op(Instr.ISC, AddrMode.AbsoluteX, 3, 7), // cycles +1 if page crossed
  0xfb: Op(Instr.ISC, AddrMode.AbsoluteY, 3, 7), // cycles +1 if page crossed
  0xe3: Op(Instr.ISC, AddrMode.IndexedIndirect, 2, 8),
  0xf3: Op(Instr.ISC, AddrMode.IndirectIndexed, 2, 8), // cycles +1 if page crossed

  0x27: Op(Instr.RLA, AddrMode.ZeroPage, 2, 5),
  0x37: Op(Instr.RLA, AddrMode.ZeroPageX, 2, 6),
  0x2f: Op(Instr.RLA, AddrMode.Absolute, 3, 6),
  0x3f: Op(Instr.RLA, AddrMode.AbsoluteX, 3, 7), // cycles +1 if page crossed
  0x3b: Op(Instr.RLA, AddrMode.AbsoluteY, 3, 7), // cycles +1 if page crossed
  0x23: Op(Instr.RLA, AddrMode.IndexedIndirect, 2, 8),
  0x33: Op(Instr.RLA, AddrMode.IndirectIndexed, 2, 8), // cycles +1 if page crossed

  0x67: Op(Instr.RRA, AddrMode.ZeroPage, 2, 5),
  0x77: Op(Instr.RRA, AddrMode.ZeroPageX, 2, 6),
  0x6f: Op(Instr.RRA, AddrMode.Absolute, 3, 6),
  0x7f: Op(Instr.RRA, AddrMode.AbsoluteX, 3, 7), // cycles +1 if page crossed
  0x7b: Op(Instr.RRA, AddrMode.AbsoluteY, 3, 7), // cycles +1 if page crossed
  0x63: Op(Instr.RRA, AddrMode.IndexedIndirect, 2, 8),
  0x73: Op(Instr.RRA, AddrMode.IndirectIndexed, 2, 8), // cycles +1 if page crossed

  0x07: Op(Instr.SLO, AddrMode.ZeroPage, 2, 5),
  0x17: Op(Instr.SLO, AddrMode.ZeroPageX, 2, 6),
  0x0f: Op(Instr.SLO, AddrMode.Absolute, 3, 6),
  0x1f: Op(Instr.SLO, AddrMode.AbsoluteX, 3, 7), // cycles +1 if page crossed
  0x1b: Op(Instr.SLO, AddrMode.AbsoluteY, 3, 7), // cycles +1 if page crossed
  0x03: Op(Instr.SLO, AddrMode.IndexedIndirect, 2, 8),
  0x13: Op(Instr.SLO, AddrMode.IndirectIndexed, 2, 8), // cycles +1 if page crossed

  0x47: Op(Instr.SRE, AddrMode.ZeroPage, 2, 5),
  0x57: Op(Instr.SRE, AddrMode.ZeroPageX, 2, 6),
  0x4f: Op(Instr.SRE, AddrMode.Absolute, 3, 6),
  0x5f: Op(Instr.SRE, AddrMode.AbsoluteX, 3, 7), // cycles +1 if page crossed
  0x5b: Op(Instr.SRE, AddrMode.AbsoluteY, 3, 7), // cycles +1 if page crossed
  0x43: Op(Instr.SRE, AddrMode.IndexedIndirect, 2, 8),
  0x53: Op(Instr.SRE, AddrMode.IndirectIndexed, 2, 8), // cycles +1 if page crossed

  0x80: Op(Instr.SKB, AddrMode.Immediate, 2, 2),
  0x82: Op(Instr.SKB, AddrMode.Immediate, 2, 2),
  0x89: Op(Instr.SKB, AddrMode.Immediate, 2, 2),
  0xc2: Op(Instr.SKB, AddrMode.Immediate, 2, 2),
  0xe2: Op(Instr.SKB, AddrMode.Immediate, 2, 2),

  0x0c: Op(Instr.IGN, AddrMode.Absolute, 3, 4),
  0x1c: Op(Instr.IGN, AddrMode.AbsoluteX, 3, 4), // cycles +1 if page crossed
  0x3c: Op(Instr.IGN, AddrMode.AbsoluteX, 2, 4), // cycles +1 if page crossed
  0x5c: Op(Instr.IGN, AddrMode.AbsoluteX, 2, 4), // cycles +1 if page crossed
  0x7c: Op(Instr.IGN, AddrMode.AbsoluteX, 2, 4), // cycles +1 if page crossed
  0xdc: Op(Instr.IGN, AddrMode.AbsoluteX, 2, 4), // cycles +1 if page crossed
  0xfc: Op(Instr.IGN, AddrMode.AbsoluteX, 2, 4), // cycles +1 if page crossed
  0x04: Op(Instr.IGN, AddrMode.ZeroPage, 2, 3),
  0x44: Op(Instr.IGN, AddrMode.ZeroPage, 2, 3),
  0x64: Op(Instr.IGN, AddrMode.ZeroPage, 2, 3),
  0x14: Op(Instr.IGN, AddrMode.ZeroPageX, 2, 4),
  0x34: Op(Instr.IGN, AddrMode.ZeroPageX, 2, 4),
  0x54: Op(Instr.IGN, AddrMode.ZeroPageX, 2, 4),
  0x74: Op(Instr.IGN, AddrMode.ZeroPageX, 2, 4),
  0xd4: Op(Instr.IGN, AddrMode.ZeroPageX, 2, 4),
  0xf4: Op(Instr.IGN, AddrMode.ZeroPageX, 2, 4),
};
