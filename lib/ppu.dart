import 'package:flutter_nes/bus.dart';
import 'package:flutter_nes/cpu.dart';
import 'package:flutter_nes/memory.dart';
import 'package:flutter_nes/util.dart';

import 'package:flutter_nes/palette.dart';

/* Frame
 * one Frame is two-dimensional int array which int mean the pixel color.
 * so one Frame output a 256x240 two-dimensional array.
*/

typedef FrameForEachPixelCallback(int x, int y, int color);

class Frame {
  Frame() {
    _pixels = List.generate(height, (n) => List.generate(width, (index) => NES_SYS_PALETTES[0x02]));
  }

  List<List<int>> _pixels;

  final int height = 240;
  final int width = 256;

  void setPixel(int x, int y, int color) {
    _pixels[y][x] = color;
  }

  int getPixel(int x, int y) {
    return _pixels[y][x];
  }

  void forEachPixel(FrameForEachPixelCallback fn) {
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        fn(x, y, _pixels[y][x]);
      }
    }
  }
}

class PPU {
  PPU(this.bus);

  // scanlines info refer: https://wiki.nesdev.com/w/index.php/PPU_rendering
  static const int CYCLES_PER_SCANLINE = 341;
  static const int SCANLINE_PER_FRAME = 262;
  static const int VBLANK_START_AT = 241;

  BUS bus;

  // all PPU registers see: https://wiki.nesdev.com/w/index.php/PPU_registers
  // Controller ($2000) > write
  // 7  bit  0
  // ---- ----
  // VPHB SINN
  // |||| ||||
  // |||| ||++- Base nametable address
  // |||| ||    (0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00)
  // |||| |+--- VRAM address increment per CPU read/write of PPUDATA
  // |||| |     (0: add 1, going across; 1: add 32, going down)
  // |||| +---- Sprite pattern table address for 8x8 sprites
  // ||||       (0: $0000; 1: $1000; ignored in 8x16 mode)
  // |||+------ Background pattern table address (0: $0000; 1: $1000)
  // ||+------- Sprite size (0: 8x8 pixels; 1: 8x16 pixels)
  // |+-------- PPU master/slave select
  // |          (0: read backdrop from EXT pins; 1: output color on EXT pins)
  // +--------- Generate an NMI at the start of the
  //            vertical blanking inter.val (0: off; 1: on)
  Int8 _regPPUCTRL;

  // Mask ($2001) > write
  // 7  bit  0
  // ---- ----
  // BGRs bMmG
  // |||| ||||
  // |||| |||+- Greyscale (0: normal color, 1: produce a greyscale display)
  // |||| ||+-- 1: Show background in leftmost 8 pixels of screen, 0: Hide
  // |||| |+--- 1: Show sprites in leftmost 8 pixels of screen, 0: Hide
  // |||| +---- 1: Show background
  // |||+------ 1: Show sprites
  // ||+------- Emphasize red (green on PAL/Dendy)
  // |+-------- Emphasize green (red on PAL/Dendy)
  // +--------- Emphasize blue
  Int8 _regPPUMASK;

  bool get greyscaleEnabled => _regPPUMASK.getBit(0) == 1;
  bool get backgroundLeftRenderEnabled => _regPPUMASK.getBit(1) == 1;
  bool get spritesLeftRenderEnabled => _regPPUMASK.getBit(2) == 1;
  bool get backgroundRenderEnabled => _regPPUMASK.getBit(3) == 1;
  bool get spritesRenderEnabled => _regPPUMASK.getBit(4) == 1;

  // Status ($2002) < read
  // 7  bit  0
  // ---- ----
  // VSO. ....
  // |||| ||||
  // |||+-++++- Least significant bits previously written into a PPU register
  // |||        (due to register not being updated for this address)
  // ||+------- Sprite overflow. The intent was for this flag to be set
  // ||         whenever more than eight sprites appear on a scanline, but a
  // ||         hardware bug causes the actual behavior to be more complicated
  // ||         and generate false positives as well as false negatives; see
  // ||         PPU sprite e.valuation. This flag is set during sprite
  // ||         e.valuation and cleared at dot 1 (the second dot) of the
  // ||         pre-render line.
  // |+-------- Sprite 0 Hit.  Set when a nonzero pixel of sprite 0 overlaps
  // |          a nonzero background pixel; cleared at dot 1 of the pre-render
  // |          line.  Used for raster timing.
  // +--------- Vertical blank has started (0: not in vblank; 1: in vblank).
  //            Set at dot 1 of line 241 (the line *after* the post-render
  //            line); cleared after reading $2002 and at dot 1 of the
  //            pre-render line.
  Int8 _regPPUSTATUS;

  // OAM(Object Attribute Memory) address ($2003) > write
  Int8 _regOAMADDR;

  // OAM data ($2004) <> read/write
  // The OAM (Object Attribute Memory) is internal memory inside the PPU that contains a display list of up to 64 sprites,
  // where each sprite's information occupies 4 bytes. So OAM takes 256 bytes
  Memory _OAM = Memory(0xff); //

  int getOAMDATA() => _OAM.read(_regOAMADDR.val);
  void setOAMDATA(int value) {
    _OAM.write(_regOAMADDR.val, value);
    _regOAMADDR += Int8(1);
  }

  // Scroll ($2005) >> write x2
  // upper byte mean x scroll.
  // lower byte mean y scroll.
  int _regPPUSCROLL; // 16-bit
  int _scrollWrite = 0; // 0: write PPUSCROLL upper bits, 1: write lower bits

  // VRAM Address ($2006) >> write x2
  int _regPPUADDR; // 16-bit
  int _addrWrite = 0; // 0: write PPUADDR upper bits, 1: write lower bits
  int _regPPUTMPADDR; // VRAM temporary address, used in PPU

  // see: https://wiki.nesdev.com/w/index.php/PPU_registers#The_PPUDATA_read_buffer_.28post-fetch.29
  int _ppuDataBuffer;

  // Data ($2007) <> read/write
  // this is the port that CPU read/write data via VRAM.
  int getPPUDATA() {
    int vramData = bus.ppuRead(_regPPUADDR);
    int value = vramData;

    if (_regPPUADDR % 0x4000 < 0x3f00) {
      value = _ppuDataBuffer;
      _ppuDataBuffer = vramData; // update data buffer with vram data
    } else {
      // when reading palttes, the buffer data is the mirrored nametable data that would appear "underneath" the palette.
      _ppuDataBuffer = bus.ppuRead((_regPPUADDR % 0x4000) - 0x0100);
    }

    _increaseAddr();
    return value;
  }

  void setPPUDATA(int value) {
    bus.ppuWrite(_regPPUADDR, value);

    _increaseAddr();
  }

  // OAM DMA ($4014) > write
  void setOAMDMA(int value) {
    int page = value << 8;

    for (int i = 0; i < 0xff; i++) {
      _OAM.write(i, bus.cpuRead(page | i));
    }

    bus.cpu.dmaCycles = 514;
  }

  int scanLine = -1;
  int cycles = 0;
  int frames = 0;

  Frame frame = Frame();

  int get _nameTableAddress => {
        0: 0x2000,
        1: 0x2400,
        2: 0x2800,
        3: 0x2c00,
      }[_regPPUCTRL.getBits(0, 1)];

  int get _attributeTableAddress => _nameTableAddress + 0x3c0;
  int get _patternTableAddress => {
        0: 0x0000,
        1: 0x1000,
      }[_regPPUCTRL.getBit(4)];

  tick() {
    cycles++;
    // if current cycles is greater than a scanline required, enter to next scanline
    if (cycles > CYCLES_PER_SCANLINE) {
      cycles -= CYCLES_PER_SCANLINE;
      scanLine++;

      if (scanLine == SCANLINE_PER_FRAME - 1 && frames % 2 == 1) {
        scanLine = -1;
        cycles = 0;
        _regPPUSTATUS.setBit(7, 0);
        return;
      }

      // one Frame is completed.
      if (scanLine >= SCANLINE_PER_FRAME) {
        scanLine = 0;
        frames++;
        _regPPUSTATUS.setBit(7, 0);
      }

      if (scanLine == VBLANK_START_AT) {
        // trigger a NMI interrupt
        if (_regPPUCTRL.getBit(7) == 1) {
          _regPPUSTATUS.setBit(7, 1);
        }
      }

      // OAMADDR is set to 0 during each of ticks 257-320
      if (cycles >= 257 && cycles <= 320) {
        _regOAMADDR = Int8(0);
      }
    }
  }

  _renderPixel() {
    int x = cycles, y = scanLine;
  }

  // render one tile to frame.
  void _renderTile(Frame frame, int address, int offsetX, int offsetY) {
    var tile = bus.ppuReadBank(_patternTableAddress + address, 0x10);

    for (int y = 0; y < 8; y++) {
      for (int x = 7; x >= 0; x--) {
        int paletteEntry = tile[y + 8].getBit(x) << 1 | tile[y].getBit(x);
        frame.setPixel(offsetX + (7 - x), offsetY + y, _testPalette(paletteEntry));
      }
    }
  }

  int _testPalette(int entry) {
    return {
      0: NES_SYS_PALETTES[0x02],
      1: NES_SYS_PALETTES[0x05],
      2: NES_SYS_PALETTES[0x28],
      3: NES_SYS_PALETTES[0x18],
    }[entry];
  }

  _increaseAddr() {
    if (_regPPUCTRL.getBit(3) == 1) {
      _regPPUADDR += 32;
    } else {
      _regPPUADDR += 1;
    }
  }

  // registers read/write is used for CPU
  int getPPUSTATUS() {
    // Reading the status register will clear bit 7 and address latch for PPUSCROLL and PPUADDR
    _scrollWrite = 0;
    _addrWrite = 0;
    _regPPUSTATUS.setBit(7, 0);

    return _regPPUSTATUS.val;
  }

  void setPPUCTRL(int value) => _regPPUCTRL = Int8(value);
  void setPPUMASK(int value) => _regPPUMASK = Int8(value);
  void setOAMADDR(int value) => _regOAMADDR = Int8(value);
  void setPPUSCROLL(int value) {
    if (_scrollWrite == 0) {
      _regPPUADDR = value << 4;
      _scrollWrite = 1;
    } else {
      _regPPUADDR |= value;
      _scrollWrite = 0;
    }
  }

  void setPPUADDR(int value) {
    if (_regPPUSTATUS.getBit(4) == 1) {
      return;
    }

    if (_addrWrite == 0) {
      _regPPUADDR = value << 4;
      _addrWrite = 1;
    } else {
      _regPPUADDR |= value;
      _addrWrite = 0;
    }
  }

  void powerOn() {
    _regPPUCTRL = Int8(0x00);
    _regPPUMASK = Int8(0x00);
    _regPPUSTATUS = Int8(0xa0); // 1010 0000
    _regOAMADDR = Int8(0x00);
    _regPPUSCROLL = 0x00;
    _regPPUADDR = 0x00;
  }

  void reset() {
    _regPPUCTRL = Int8(0x00);
    _regPPUMASK = Int8(0x00);
    _regPPUSTATUS = Int8(_regPPUSTATUS.getBit(7) << 7);
    _regOAMADDR = Int8(0x00);
    _regPPUSCROLL = 0x00;
    // PPUADDR register is unchange

    _scrollWrite = 0;
    _addrWrite = 0;
  }
}
