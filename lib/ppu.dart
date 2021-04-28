import 'package:flutter_nes/bus.dart';
import 'package:flutter_nes/memory.dart';
import 'package:flutter_nes/util.dart';
import 'package:flutter_nes/palette.dart';
import 'package:flutter_nes/frame.dart';

const int CYCLES_PER_SCANLINE = 341;
const int SCANLINE_PER_FRAME = 262;
const int POST_SCANLINE = 240;
const int VBLANK_START_AT = 241;

class PPU {
  PPU(this.bus);

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
  //            vertical blanking inter.() (0: off; 1: on)
  int _regPPUCTRL;
  int get _addrStepSize => _regPPUCTRL.getBit(3) == 1 ? 32 : 1;

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
  int _regPPUMASK;

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
  int _regPPUSTATUS;

  // OAM(Object Attribute Memory) address ($2003) > write
  int _regOAMADDR;

  // OAM(SPR-RAM) data ($2004) <> read/write
  // The OAM (Object Attribute Memory) is internal memory inside the PPU that contains a display list of up to 64 sprites,
  // where each sprite's information occupies 4 bytes. So OAM takes 256 bytes
  Memory _OAM = Memory(0xff);

  int getOAMDATA() => _OAM.read(_regOAMADDR);
  void setOAMDATA(int value) {
    _OAM.write(_regOAMADDR, value);
    _regOAMADDR += 1;
  }

  // Scroll ($2005) >> write x2
  // upper byte mean x scroll.
  // lower byte mean y scroll.
  int _regPPUSCROLL; // 16-bit
  int _scrollWriteToggle = 0; // 0: write PPUSCROLL upper bits, 1: write lower bits

  // VRAM Address ($2006) >> write x2
  int _regPPUADDR; // 16-bit
  int _addrWriteToggle = 0; // 0: write PPUADDR upper bits, 1: write lower bits
  int _regPPUTMPADDR; // VRAM temporary address, used in PPU

  // see: https://wiki.nesdev.com/w/index.php/PPU_registers#The_PPUDATA_read_buffer_.28post-fetch.29
  // the first result should be discard when CPU reading PPUDATA
  int _ppuDataBuffer = 0x00;

  // Data ($2007) <> read/write
  // this is the port that CPU read/write data via VRAM.
  int getPPUDATA() {
    int vramData = bus.ppuRead(_regPPUADDR);
    int value;

    if (_regPPUADDR % 0x4000 < 0x3f00) {
      value = _ppuDataBuffer;
      _ppuDataBuffer = vramData; // update data buffer with vram data
    } else {
      // when reading palttes, the buffer data is the mirrored nametable data that would appear "underneath" the palette.
      value = _ppuDataBuffer = vramData;
    }

    _regPPUADDR += _addrStepSize;
    return value;
  }

  void setPPUDATA(int value) {
    print("set PPU data, ${_regPPUADDR.toHex()}: ${value.toHex(2)} ");
    bus.ppuWrite(_regPPUADDR, value);

    _regPPUADDR += _addrStepSize;
  }

  // OAM DMA ($4014) > write
  void setOAMDMA(int value) {
    int page = value << 8;

    int oamAddr = _regOAMADDR;
    for (int i = 0; i < 0xff; i++) {
      _OAM.write(oamAddr + i, bus.cpuRead(page + i));
    }
  }

  int scanLine = -1;
  int cycle = 0;
  int frames = 0;

  int _nameTableByte = 0;
  int _attribute2Bit = 0;
  int _tile16Bit = 0;

  bool get isScanLineVisible => scanLine >= 0 && scanLine < POST_SCANLINE;
  bool get isScanLineVBlanking => scanLine >= VBLANK_START_AT;
  bool get isCycleVisible => cycle >= 1 && cycle <= 256;

  Frame frame = Frame();

  _renderPixel() {
    int x = cycle - 1, y = scanLine;

    // this is background render
    for (int i = 7; i >= 0; i--) {
      int paletteEntry = bus.ppuRead(0x3f00 + _attribute2Bit << 2 | _tile16Bit.getBit(i + 8) << 1 | _tile16Bit.getBit(i));
      frame.setPixel(x, y, NES_SYS_PALETTES[paletteEntry]);
    }

    // @TODO sprites render
  }

  _fetchNameTableByte() {
    int addr = 0x2000 | (_regPPUADDR & 0x0fff);
    _nameTableByte = bus.ppuRead(addr);
  }

  _fetchAttributeByte() {
    int nameTableByteIndex = _regPPUADDR % 0x03c0;
    int attributeAddress = 0x23c0 + (nameTableByteIndex / 0x10).floor();
    int attributeByte = bus.ppuRead(attributeAddress);
    int positionNum = ((nameTableByteIndex % 16) / 4).floor();

    _attribute2Bit = (attributeByte >> positionNum * 2) & 0x0003; // 0b11
  }

  _fetchNameTableTileData() {
    int lowerTileByte = bus.ppuRead(_nameTableByte);
    int upperTileByte = bus.ppuRead(_nameTableByte + 0x08);

    _tile16Bit = upperTileByte << 8 | lowerTileByte;
  }

  _evaluateSprites() {}

  tick() {
    // every cycle behaivor is here: https://wiki.nesdev.com/w/index.php/PPU_rendering#Line-by-line_timing

    if (isCycleVisible && isScanLineVisible) {
      _renderPixel();

      if (cycle == 257) {
        _evaluateSprites();
      }
    }

    if (cycle >= 1 && cycle <= 336) {
      switch (cycle % 8) {
        case 1:
          _fetchNameTableByte();
          break;
        case 3:
          _fetchAttributeByte();
          break;
        case 5:
          _fetchNameTableTileData();
          break;
        case 7: // this case has done by last case.
          break;
      }
    }

    _updateCycles();
  }

  _updateCycles() {
    cycle++;

    // if current cycles is greater than a scanline required, enter to next scanline
    if (cycle > CYCLES_PER_SCANLINE) {
      cycle = 0;
      scanLine++;
      return;
    }

    // OAMADDR is set to 0 during each of ticks 257-320
    if (cycle >= 257 && cycle <= 320) {
      _regOAMADDR = 0;
    }

    if (scanLine == SCANLINE_PER_FRAME - 1 && frames % 2 == 1) {
      scanLine = -1;
      cycle = 0;
      _regPPUSTATUS = _regPPUSTATUS.setBit(7, 0);
      return;
    }

    // one Frame is completed.
    if (scanLine > SCANLINE_PER_FRAME) {
      scanLine = 0;
      frames++;
      _regPPUSTATUS = _regPPUSTATUS.setBit(7, 0);
      return;
    }

    if (scanLine == VBLANK_START_AT) {
      _regPPUSTATUS = _regPPUSTATUS.setBit(7, 1);
      // trigger a NMI interrupt
      if (_regPPUCTRL.getBit(7) == 1) {
        bus.cpu.nmiOccurred = true;
      }
    }
  }

  // render one tile to frame.
  // void _renderTile(Frame frame, int address, int offsetX, int offsetY) {
  //   var tile = bus.ppuReadBank(_patternTableAddress + address, 0x10);

  //   for (int y = 0; y < 8; y++) {
  //     for (int x = 7; x >= 0; x--) {
  //       int paletteEntry = tile[y + 8].getBit(x) << 1 | tile[y].getBit(x);
  //       frame.setPixel(offsetX + (7 - x), offsetY + y, _testPalette(paletteEntry));
  //     }
  //   }
  // }

  // int _testPalette(int entry) {
  //   return {
  //     0: NES_SYS_PALETTES[0x02],
  //     1: NES_SYS_PALETTES[0x05],
  //     2: NES_SYS_PALETTES[0x28],
  //     3: NES_SYS_PALETTES[0x18],
  //   }[entry];
  // }

  // registers read/write is used for CPU
  int getPPUSTATUS() {
    // Reading the status register will clear bit 7 and address latch for PPUSCROLL and PPUADDR
    int val = _regPPUSTATUS;
    _scrollWriteToggle = 0;
    _addrWriteToggle = 0;
    _regPPUSTATUS = _regPPUSTATUS.setBit(7, 0);

    return val;
  }

  void setPPUCTRL(int value) => _regPPUCTRL = value;
  void setPPUMASK(int value) => _regPPUMASK = value;
  void setOAMADDR(int value) => _regOAMADDR = value;
  void setPPUSCROLL(int value) {
    if (_scrollWriteToggle == 0) {
      _regPPUADDR = value << 4;
      _scrollWriteToggle = 1;
    } else {
      _regPPUADDR |= value;
      _scrollWriteToggle = 0;
    }
  }

  void setPPUADDR(int value) {
    if (_regPPUSTATUS.getBit(4) == 1) {
      return;
    }

    if (_addrWriteToggle == 0) {
      _regPPUADDR = value << 4;
      _addrWriteToggle = 1;
    } else {
      _regPPUADDR |= value;
      _addrWriteToggle = 0;
    }
  }

  void powerOn() {
    _regPPUCTRL = 0x00;
    _regPPUMASK = 0x00;
    _regPPUSTATUS = 0x00;
    _regOAMADDR = 0x00;
    _regPPUSCROLL = 0x00;
    _regPPUADDR = 0x00;
  }

  void reset() {
    _regPPUCTRL = 0x00;
    _regPPUMASK = 0x00;
    _regPPUSTATUS = _regPPUSTATUS.getBit(7) << 7;
    _regPPUSCROLL = 0x00;
    _ppuDataBuffer = 0x00;

    _scrollWriteToggle = 0;
    _addrWriteToggle = 0;
  }
}
