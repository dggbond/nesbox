part of "cpu.dart";

// ---------------------------------------
// here is the implementation of all the addressing modes;

class AddressModeResult {
  AddressModeResult({
    required this.bytes,
    required this.pcStepSize,
    required this.address,
    this.pageCrossed = false,
  });

  int bytes; // next 8bit or 16bit after pc register
  int pcStepSize;
  int address; // target address
  bool pageCrossed;
}

class AddressMode {
  AddressMode({required this.call, required this.display});

  final AddressModeResult Function(CPU cpu) call;

  final String Function(Op op) display;
}

// one page is 8-bit size;
bool isPageCrossed(int addr1, int addr2) {
  return addr1 & 0xff00 != addr2 & 0xff00;
}

// Addressing mode functions
// see: https://wiki.nesdev.com/w/index.php/CPU_addressing_modes
final ZeroPage = AddressMode(
    call: (CPU cpu) {
      final bytes = cpu.read(cpu.regPC + 1);

      return AddressModeResult(
        bytes: bytes,
        address: bytes & 0xff,
        pcStepSize: 2,
      );
    },
    display: (op) => "");

final ZeroPageX = AddressMode(
    call: (CPU cpu) {
      final bytes = cpu.read(cpu.regPC + 1);

      return AddressModeResult(
        bytes: bytes,
        address: (bytes + cpu.regX) & 0xff,
        pcStepSize: 2,
      );
    },
    display: (op) => "");

final ZeroPageY = AddressMode(
    call: (CPU cpu) {
      final bytes = cpu.read(cpu.regPC + 1);
      return AddressModeResult(
        bytes: bytes,
        address: (bytes + cpu.regY) & 0xff,
        pcStepSize: 2,
      );
    },
    display: (op) => "");

final Absolute = AddressMode(
    call: (CPU cpu) {
      final bytes = cpu.read16Bit(cpu.regPC + 1);

      return AddressModeResult(
        bytes: bytes,
        address: bytes,
        pcStepSize: 3,
      );
    },
    display: (op) => "");

final AbsoluteX = AddressMode(
    call: (CPU cpu) {
      final bytes = cpu.read16Bit(cpu.regPC + 1);

      return AddressModeResult(
        bytes: bytes,
        address: bytes + cpu.regX,
        pcStepSize: 3,
        pageCrossed: isPageCrossed(bytes, bytes + cpu.regX),
      );
    },
    display: (op) => "");

final AbsoluteY = AddressMode(
    call: (CPU cpu) {
      final bytes = cpu.read16Bit(cpu.regPC + 1);

      return AddressModeResult(
        bytes: bytes,
        address: bytes + cpu.regY,
        pcStepSize: 3,
        pageCrossed: isPageCrossed(bytes, bytes + cpu.regY),
      );
    },
    display: (op) => "");

final Implied = AddressMode(
    call: (CPU cpu) {
      return AddressModeResult(bytes: 0, pcStepSize: 1, address: 0);
    },
    display: (op) => "");
final Accumulator = AddressMode(
    call: (CPU cpu) {
      return AddressModeResult(bytes: 0, pcStepSize: 1, address: 0);
    },
    display: (op) => "");

final Immediate = AddressMode(
    call: (CPU cpu) {
      final bytes = cpu.read(cpu.regPC + 1);

      return AddressModeResult(bytes: bytes, pcStepSize: 2, address: cpu.regPC + 1);
    },
    display: (op) => "");

final Relative = AddressMode(
    call: (CPU cpu) {
      final bytes = cpu.read(cpu.regPC + 1);

      // offset is a signed integer
      int offset = bytes >= 0x80 ? bytes - 0x100 : bytes;

      return AddressModeResult(bytes: bytes, pcStepSize: 2, address: cpu.regPC + 2 + offset);
    },
    display: (op) => "");

final Indirect = AddressMode(
    call: (CPU cpu) {
      final bytes = cpu.read16Bit(cpu.regPC + 1);

      return AddressModeResult(bytes: bytes, pcStepSize: 3, address: cpu.read16BitUncrossPage(bytes));
    },
    display: (op) => "");

final IndexedIndirect = AddressMode(
    call: (CPU cpu) {
      final bytes = cpu.read(cpu.regPC + 1);

      return AddressModeResult(
          bytes: bytes, pcStepSize: 2, address: cpu.read16BitUncrossPage((bytes + cpu.regX) & 0xff));
    },
    display: (op) => "");

final IndirectIndexed = AddressMode(
    call: (CPU cpu) {
      final bytes = cpu.read(cpu.regPC + 1);
      final address = cpu.read16BitUncrossPage(bytes) + cpu.regY;

      return AddressModeResult(
        bytes: bytes,
        pcStepSize: 2,
        address: address,
        pageCrossed: isPageCrossed(address, address - cpu.regY),
      );
    },
    display: (op) => "");
