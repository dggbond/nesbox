library flutter_nes.cpu;

import 'cpu.dart';

nmi(CPU cpu) {
  cpu.pushStack16Bit(cpu.regPC);
  cpu.pushStack(cpu.regPS);

  cpu.regPC = cpu.read16Bit(0xfffa);

  // Set the interrupt disable flag to prevent further interrupts.
  cpu.fInterruptDisable = 1;

  cpu.cycles += 7;
}

irq(CPU cpu) {
  // IRQ is ignored when interrupt disable flag is set.
  if (cpu.fInterruptDisable == 1) {
    return;
  }

  cpu.pushStack16Bit(cpu.regPC);
  cpu.pushStack(cpu.regPS);

  cpu.fInterruptDisable = 1;

  cpu.regPC = cpu.read16Bit(0xfffe);

  cpu.cycles += 7;
}

reset(CPU cpu) {
  cpu.regSP = 0xfd;
  cpu.regPC = cpu.read16Bit(0xfffc);
  cpu.regPS = 0x24;

  cpu.cycles += 7;
}
