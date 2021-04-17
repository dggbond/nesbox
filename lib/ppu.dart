import 'dart:typed_data';

import 'package:flutter_nes/bus.dart';
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

  BUS bus;

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
  Int8 _regOAMDATA;

  // Scroll ($2005) >> write x2
  // upper byte mean x scroll.
  // lower byte mean y scroll.
  int _regPPUSCROLL; // 16-bit
  int _scrollWrite = 0; // 0: write PPUSCROLL upper byte, 1: write lower byte

  // VRAM Address ($2006) >> write x2
  int _regPPUADDR; // 16-bit
  int _addrWrite = 0; // 0: write PPUADDR upper byte, 1: write lower byte

  // VRAM temporary address
  int _regPPUTMPADDR;

  // Data ($2007) <> read/write
  Int8 _regPPUDATA;

  // OAM DMA ($4014) > write
  Int8 _regOMADMA;

  // the scan line numbers;
  int scanLine = -1;
  int cycles = 0;

  void _scanline() {}

  void _renderPixel() {}

  void _fetchNameTable() {
    int nameTable = bus.ppuRead(_regPPUADDR);
  }

  Frame renderTiles() {
    Frame frame = Frame();

    for (int i = 0; i < 0x100; i++) {
      _renderTile(i, frame);
    }
    return frame;
  }

  void _renderTile(int tileNumber, Frame frame) {
    var tile = bus.ppuReadBank(tileNumber * 16, 16);

    for (int y = 0; y < 8; y++) {
      for (int x = 7; x >= 0; x--) {
        int paletteEntry = tile[y + 8].getBit(x) << 1 | tile[y].getBit(x);
        frame.setPixel((tileNumber % 32) * 8 + (7 - x), (tileNumber / 32).floor() * 8 + y, _testPalette(paletteEntry));
      }
    }
  }

  int _testPalette(int entry) {
    return {
      0: NES_SYS_PALETTES[0x02],
      1: NES_SYS_PALETTES[0x05],
      2: NES_SYS_PALETTES[0x27],
      3: NES_SYS_PALETTES[0x17],
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

  int getOAMDATA() => _regOAMDATA.val;
  int getPPUDATA() {
    _regPPUDATA = Int8(bus.ppuRead(_regPPUADDR));

    _increaseAddr();
    return _regPPUDATA.val;
  }

  void setPPUCTRL(int value) => _regPPUCTRL = Int8(value);
  void setPPUMASK(int value) => _regPPUMASK = Int8(value);
  void settOAMADDR(int value) => _regOAMADDR = Int8(value);
  void setOAMDATA(int value) => _regOAMDATA = Int8(value);
  void setPPUSCROLL(int value) {
    if (_scrollWrite == 0) {
      _regPPUADDR = value << 2;
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
      _regPPUADDR = value << 2;
      _addrWrite = 1;
    } else {
      _regPPUADDR |= value;
      _addrWrite = 0;
    }
  }

  void setPPUDATA(int value) {
    _regPPUDATA = Int8(value);
    _increaseAddr();
  }

  void setOMADMA(int value) => _regOMADMA = Int8(value);

  void powerOn() {
    _regPPUCTRL = Int8(0x00);
    _regPPUMASK = Int8(0x00);
    _regPPUSTATUS = Int8(0xa0); // 1010 0000
    _regOAMADDR = Int8(0x00);
    _regPPUSCROLL = 0x00;
    _regPPUADDR = 0x00;
    _regPPUDATA = Int8(0x00);
  }

  void reset() {
    _regPPUCTRL = Int8(0x00);
    _regPPUMASK = Int8(0x00);
    _regPPUSTATUS = Int8(_regPPUSTATUS.getBit(7) << 7);
    _regOAMADDR = Int8(0x00);
    _regPPUSCROLL = 0x00;
    _regPPUDATA = Int8(0x00);
    // PPUADDR register is unchange

    _scrollWrite = 0;
    _addrWrite = 0;
  }
}
