library flutter_nes.ppu;

import 'dart:typed_data';

import 'bus.dart';
import 'util/util.dart';
import 'frame.dart';
import 'palette.dart';
import 'cpu/interrupt.dart' as cpu_interrupt;

class PPU {
  BUS bus;

  // https://wiki.nesdev.com/w/index.php/PPUregisters

  // Controller ($2000) > write
  int fBaseNameTable = 0; // 0 = $2000; 1 = $2400; 2 = $2800; 3 = $2C00
  int fAddressIncrement = 0; // 0: add 1, going across; 1: add 32, going down
  int fSpritePatternTable = 0; // 0: $0000; 1: $1000; ignored in 8x16 mode
  int fBackPatternTable = 0; // 0: $0000; 1: $1000
  int fSpriteSize = 0; // 0: 8x8 pixels; 1: 8x16 pixels
  int fSelect = 0; // 0: read backdrop from EXT pins; 1: output color on EXT pins

  void set regController(int value) {
    fBaseNameTable = value & 0x3;
    fAddressIncrement = value >> 2 & 0x1;
    fSpritePatternTable = value >> 3 & 0x1;
    fBackPatternTable = value >> 4 & 0x1;
    fSpriteSize = value >> 5 & 0x1;
    fSelect = value >> 6 & 0x1;
    fNmiOutput = value >> 7 & 0x1;

    // t: ...GH.. ........ <- d: ......GH
    // <used elsewhere> <- d: ABCDEF..
    regT = (regT & 0xf3ff) | (value & 0x03) << 10;
  }

  // Mask ($2001) > write
  int fGeryScale = 0; // 0: normal color, 1: produce a greyscale display
  int fBackLeftMost = 0; // 1: Show background in leftmost 8 pixels of screen, 0: Hide
  int fSpriteLeftMost = 0; // 1: Show sprites in leftmost 8 pixels of screen, 0: Hide
  int fShowBack = 0; // 1: Show background
  int fShowSprite = 0; // 1: Show sprites
  int fEmphasizeRed = 0; // green on PAL/Dendy
  int fEmphasizeGreen = 0; // red on PAL/Dendy
  int fEmphasizeBlue = 0;

  void set regMask(int value) {
    fGeryScale = value & 0x1;
    fBackLeftMost = value >> 1 & 0x1;
    fSpriteLeftMost = value >> 2 & 0x1;
    fShowBack = value >> 3 & 0x1;
    fShowSprite = value >> 4 & 0x1;
    fEmphasizeRed = value >> 5 & 0x1;
    fEmphasizeGreen = value >> 6 & 0x1;
    fEmphasizeBlue = value >> 7 & 0x1;
  }

  // Status ($2002) < read
  int fSign = 0;
  int fSpriteOverflow = 0;
  int fSpirteZeroHit = 0;
  int fVerticalBlanking = 0;

  int get regStatus {
    int status = (fSign & 0x1f) | fSpriteOverflow << 5 | fSpirteZeroHit << 6;

    status |= fNmiOccurred << 7;
    fNmiOccurred = 0;

    // w:                  <- 0
    regW = 0;

    return status;
  }

  // OAM address ($2003) > write
  int regOamAddress = 0x00;

  // The OAM (Object Attribute Memory) is internal memory inside the PPU that contains a display list of up to 64 sprites,
  // where each sprite's information occupies 4 bytes. So OAM takes 256 bytes
  Uint8List oam = Uint8List(0xff);

  // OAM(SPR-RAM) data ($2004) <> read/write
  int get regOamData => oam[regOamAddress];
  void set regOamData(int value) => oam[regOamAddress++];

  // https://wiki.nesdev.org/w/index.php?title=PPU_scrolling
  // reg V bits map
  // yyy NN YYYYY XXXXX
  // ||| || ||||| +++++-- coarse X scroll
  // ||| || +++++-------- coarse Y scroll
  // ||| ++-------------- nametable select
  // +++----------------- fine Y scroll
  int regV = 0x00; // current VRAM Address 15bits
  int regT = 0x00; // temporary  VRAM address, 15bits
  int regX = 0x0; // fine x scroll 3bits;
  int regW = 0; // First or second write toggle, 1bit

  // Scroll ($2005) >> write x2
  void set regScroll(int value) {
    if (regW == 0) {
      // first write
      // t: ....... ...ABCDE <- d: ABCDE...
      // x:              FGH <- d: .....FGH
      // w:                  <- 1
      regT = (regT & 0xffd0) | (value & 0xf8) >> 3;
      regX = value & 0x07;
      regW = 1;
    } else {
      // second write
      // t: FGH..AB CDE..... <- d: ABCDEFGH
      // w:                  <- 0
      regT &= 0x8c1f;
      regT |= (value & 0x03) << 12;
      regT |= (value & 0xf8) << 2;
      regW = 0;
    }
  }

  // Address ($2006) >> write x2
  void set regAddress(int value) {
    if (regW == 0) {
      // first write
      // t: .CDEFGH ........ <- d: ..CDEFGH
      //        <unused>     <- d: AB......
      // t: Z...... ........ <- 0 (bit Z is cleared)
      // w:                  <- 1

      regT = (regT & 0xc0ff) | (value & 0x3f) << 8;
      regT = regT.setBit(14, 0);
      regW = 1;
    } else {
      // second write
      // t: ....... ABCDEFGH <- d: ABCDEFGH
      // v: <...all bits...> <- t: <...all bits...>
      // w:                  <- 0

      regT = (regT & 0xff00) | value;
      regV = regT;
      regW = 0;
    }
  }

  // see: https://wiki.nesdev.com/w/index.php/PPUregisters#The_PPUDATA_read_buffer_.28post-fetch.29
  // the first result should be discard when CPU reading PPUDATA
  int dataBuffer = 0x00;

  // Data ($2007) <> read/write
  // this is the port that CPU read/write data via VRAM.
  int get regData {
    int vramData = read(regV);
    int value;

    if (regV % 0x4000 < 0x3f00) {
      value = dataBuffer;
      dataBuffer = vramData; // update data buffer with vram data
    } else {
      // when reading palttes, the buffer data is the mirrored nametable data that would appear "underneath" the palette.
      value = vramData;
      dataBuffer = read(regV - 0x1000);
    }

    regV += fAddressIncrement == 1 ? 32 : 1;
    return value;
  }

  void set regData(int value) {
    write(regV, value);
    regV += fAddressIncrement == 1 ? 32 : 1;
  }

  // OAM DMA ($4014) > write
  void set regDMA(int value) {
    int page = value << 8;

    for (int address = page; address < page + 0xff; address++) {
      oam[regOamAddress++] = bus.cpu.read(address);
    }
  }

  // https://wiki.nesdev.org/w/index.php?title=NMI
  int fNmiOccurred = 0; // 1bit
  int fNmiOutput = 0; // 1bit, 0: 0ff, 1: on

  checkNmiPulled() {
    if (fNmiOccurred == 1 && fNmiOutput == 1) {
      bus.cpu.interrupt = cpu_interrupt.nmi;
    }
  }

  int scanline = 0;
  int cycle = 0;
  int frames = 0;
  bool fOddFrames = false;

  int nameTableByte = 0;
  int attributeTableByte = 0;
  int lowBGTileByte = 0;
  int highBGTileByte = 0;
  int bgTile = 0;

  Frame frame = Frame();

  _renderPixel() {
    int x = cycle - 1, y = scanline;

    int currentTile = bgTile & 0xff;
    int entry = currentTile >> ((7 - regX) * 4);

    frame.setPixel(x, y, NES_SYS_PALETTES[entry]);
  }

  _fetchNameTableByte() {
    int addr = 0x2000 | (regV & 0x0FFF);
    nameTableByte = read(addr);
  }

  _fetchAttributeTableByte() {
    int addr = 0x23c0 | (regV & 0x0c00) | ((regV >> 4) & 0x38) | ((regV >> 2) & 0x07);
    attributeTableByte = read(addr);
  }

  _fetchLowBGTileByte() {
    int fineY = (regV >> 12) & 0x7;
    int addr = 0x1000 * fBackPatternTable + nameTableByte * 16 + fineY;

    lowBGTileByte = read(addr + 8);
  }

  _fetchHighBGTileByte() {
    int fineY = (regV >> 12) & 0x7;
    int addr = 0x1000 * fBackPatternTable + nameTableByte * 16 + fineY;

    lowBGTileByte = read(addr);
  }

  _composeBGTile() {
    int tile = 0;

    for (int i = 8; i >= 0; i--) {
      int lowBit = lowBGTileByte.getBit(i);
      int highBit = highBGTileByte.getBit(i);

      tile <<= 4;
      tile |= attributeTableByte | highBit << 1 | lowBit;
    }

    bgTile |= tile << 32;
  }

  _evaluateSprites() {}

  _incrementCoarseX() {
    if ((regV & 0x001f) == 31) {
      regV &= ~0x01f; // coarse X = 0
      regV ^= 0x0400; // switch horizontal nametable
    } else {
      regV++;
    }
  }

  _incrementScrollY() {
    // if fine Y < 7
    if (regV & 0x7000 != 0x7000) {
      regV += 0x1000; // increment fine Y
    } else {
      regV &= ~0x7000; // fine Y = 0

      int y = (regV & 0x03e0) >> 5; // let y = coarse Y
      if (y == 29) {
        y = 0; // coarse Y = 0
        regV ^= 0x0800; // switch vertical nametable
      } else if (y == 31) {
        y = 0; // coarse Y = 0, nametable not switched
      } else {
        y++; // increment coarse Y
      }

      regV = (regV & ~0x03e0) | (y << 5); // put coarse Y back into v
    }
  }

  // every cycle behaivor is here: https://wiki.nesdev.com/w/index.php/PPU_rendering#Line-by-line_timing
  clock() {
    checkNmiPulled();

    bool isScanlineVisible = scanline < 240;
    bool isScanlinePreRender = scanline == 261;
    bool isScanlineFetching = isScanlineVisible || isScanlinePreRender;

    bool isCycleVisible = cycle >= 1 && cycle <= 256;
    bool isCyclePreFetch = cycle >= 321 && cycle <= 336;
    bool isCycleFetching = isCycleVisible || isCyclePreFetch;

    bool isRenderingEnabled = fShowBack == 1 || fShowSprite == 1;

    // OAMADDR is set to 0 during each of ticks 257-320
    if (isScanlineFetching && cycle >= 257 && cycle <= 320) {
      regOamAddress = 0x00;
    }

    if (isRenderingEnabled) {
      if (isCycleVisible && isScanlineVisible) {
        _renderPixel();
      }

      // fetch background data
      if (isCycleFetching && isScanlineFetching) {
        // every cycle right shift the tile data for rendering;
        bgTile >>= 4;

        switch (cycle % 8) {
          case 0:
            _composeBGTile();
            break;
          case 1:
            _fetchNameTableByte();
            break;
          case 3:
            _fetchAttributeTableByte();
            break;
          case 5:
            _fetchLowBGTileByte();
            break;
          case 7:
            _fetchHighBGTileByte();
            break;
        }
      }

      // after fetch next tile
      if (isScanlineFetching && (cycle % 8 == 0)) {
        _incrementCoarseX();
      }

      if (isScanlineFetching && cycle == 256) {
        _incrementScrollY();
      }
    }

    // start vertical blanking
    if (scanline == 241 && cycle == 1) {
      fVerticalBlanking = 1;
      fNmiOccurred = 1;
      checkNmiPulled();
    } else {
      fNmiOccurred = 0;
    }

    // end vertical blanking
    if (isScanlinePreRender && cycle == 1) {
      fVerticalBlanking = 0;
      fNmiOccurred = 0;
    }

    _updateCounters();
  }

  _updateCounters() {
    if (fShowBack == 1 || fShowSprite == 1) {
      if (scanline == 261 && cycle == 339 && fOddFrames) {
        cycle = 0;
        scanline = 0;
        frames++;
        fOddFrames = !fOddFrames;
        return;
      }
    }

    cycle++;
    // one scanline is completed.
    if (cycle > 340) {
      cycle = 0;
      scanline++;
    }

    // one frame is completed.
    if (scanline > 261) {
      scanline = 0;
      frames++;
      fOddFrames = !fOddFrames;
    }
  }

  int read(int addr) => bus.ppuRead(addr);
  void write(int addr, int value) => bus.ppuWrite(addr, value);

  void reset() {
    cycle = 0;
    scanline = 0;
    frames = 0;

    regController = 0x00;
    regMask = 0x00;
    regScroll = 0x00;
    dataBuffer = 0x00;
  }
}
