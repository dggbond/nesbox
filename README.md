# Nesbox
A nes emulator written in dart without dependencies.

## Demo App
this dart package has **no other dependencies** at all, all of codes is written in the [`lib`](lib) folder.
so you can't see the game graphics if you just only run this package. if you want to see the actual effect of this emulator.
you can run the demo project [Fico](https://github.com/tilemoon/Fico)

## Getting Started
there is no package published yet.

## TODO
- [x] CPU
- [ ] PPU
- [ ] APU
- [x] ROM file parser
- [ ] Controller in keyboard
- [ ] Picture render

## Features
- [ ] Basic nes emulator
- [ ] Game speed control (2x, 4x, 8x ...)
- [ ] Controller in handle
- [ ] Save/Load game progress
- [ ] Video record
- [ ] Multiple players from WIFI or bluetooth

## References
- [NESDoc](http://nesdev.com/NESDoc.pdf)

blogs:
- [yizhang82.dev nes blogs](https://yizhang82.dev/blog/nes/)
- [I made an NES emulator. Here’s what I learned about the original Nintendo.](https://medium.com/@fogleman/i-made-an-nes-emulator-here-s-what-i-learned-about-the-original-nintendo-2e078c9b28fe)
- [writing NES Emulator in Rust](https://bugzmanov.github.io/nes_ebook/chapter_1.html)
- [NES Rendering](https://austinmorlan.com/posts/nes_rendering_overview/)

6502 CPU:
- [6502 CPU reference](https://www.masswerk.at/6502/6502_instruction_set.html#PHP)
- [emualtor101](http://www.emulator101.com/6502-emulator.html)

PPU:
- [nesdev PPU](https://wiki.nesdev.com/w/index.php/PPU)

Unoffical Opcodes(Instructions) \
there are some unoffical opcodes in nes program. these docs may help.
- [unofficial opcodes](https://wiki.nesdev.com/w/index.php/Programming_with_unofficial_opcodes)
- [undocumented_opcodes](https://github.com/ltriant/nes/blob/master/doc/undocumented_opcodes.txt)

nesfiles:
- [nesfiles](https://www.nesfiles.com/)

Tests:
- https://wiki.nesdev.org/w/index.php?title=Emulator_tests#CPU_Tests
- http://www.qmtpro.com/~nes/misc/

## Other nes emulators
- [fogleman/nes](https://github.com/fogleman/nes): written in go.
- [bfirsh/jsnes](https://github.com/bfirsh/jsnes): written in javascript.
- [yizhang82/neschan](https://github.com/yizhang82/neschan): written in c++;

## License
This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details
