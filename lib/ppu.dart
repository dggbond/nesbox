import 'bus.dart';
import 'cpu.dart';
import 'cartridge.dart' show Mirroring;
import 'memory.dart';
import 'util/number.dart';
import 'util/logger.dart';
import 'frame.dart';

const int CYCLES_PER_SCANLINE = 341;
const int SCANLINES_PER_FRAME = 262;

class Pos {
  Pos(this.x, this.y);

  int x;
  int y;
}

class PPU {
  PPU();

  BUS bus;

  // all PPU registers see: https://wiki.nesdev.com/w/index.php/PPUregisters
  // Controller ($2000) > write
  int regCTRL;
  int get baseNTAddress => {
        0: 0x2000,
        1: 0x2400,
        2: 0x2800,
        3: 0x2c00,
      }[regCTRL & 0x03];
  int get baseATAddress => baseNTAddress + 0x3c0;
  int get backgroundPTAddress => {
        0: 0x0000,
        1: 0x1000,
      }[regCTRL.getBit(4)];
  int get addrStepSize => regCTRL.getBit(3) == 1 ? 32 : 1;
  bool get enableNMI => regCTRL.getBit(7) == 1;

  void setPPUCTRL(int value) {
    logger.log('set reg ctrl ${value.toHex()}');
    regCTRL = value & 0xff;
  }

  int getPPUCTRL() => regCTRL;

  // Mask ($2001) > write
  int regMASK;
  bool get greyscaleEnabled => regMASK.getBit(0) == 1;
  bool get backgroundLeftRenderEnabled => regMASK.getBit(1) == 1;
  bool get spritesLeftRenderEnabled => regMASK.getBit(2) == 1;
  bool get backgroundRenderEnabled => regMASK.getBit(3) == 1;
  bool get spritesRenderEnabled => regMASK.getBit(4) == 1;

  void setPPUMASK(int value) => regMASK = value & 0xff;
  int getPPUMASK() => regMASK;

  // Status ($2002) < read
  int regSTATUS;
  bool get verticalBlanking => regSTATUS.getBit(7) == 1;
  bool get spriteHit => regSTATUS.getBit(6) == 1;
  bool get spriteOverflow => regSTATUS.getBit(5) == 1;

  int getPPUSTATUS() {
    // Reading the status register will clear bit 7 and address latch for PPUSCROLL and PPUADDR
    int val = regSTATUS;
    _scrollWriteUpper = true;
    _addrWriteUpper = true;
    regSTATUS = regSTATUS.setBit(7, 0);

    return val;
  }

  // OAM address ($2003) > write
  int regOAMADDR;

  void setOAMADDR(int value) => regOAMADDR = value;
  int getOAMADDR() => regOAMADDR;

  // OAM(SPR-RAM) data ($2004) <> read/write
  // The OAM (Object Attribute Memory) is internal memory inside the PPU that contains a display list of up to 64 sprites,
  // where each sprite's information occupies 4 bytes. So OAM takes 256 bytes
  Memory _spriteRAM = Memory(0xff);

  int getOAMDATA() => _spriteRAM.read(regOAMADDR);
  void setOAMDATA(int value) => _spriteRAM.write(regOAMADDR++, value);

  // Scroll ($2005) >> write x2
  // upper byte mean x scroll.
  // lower byte mean y scroll.
  int regSCROLL; // 16-bit

  // 0: write PPUSCROLL upper bits, 1: write lower bits
  bool _scrollWriteUpper = true;
  int get scrollX => regSCROLL & 0xf0 >> 4;
  int get scrollY => regSCROLL & 0xf;

  void setPPUSCROLL(int value) {
    if (_scrollWriteUpper) {
      regSCROLL = (regSCROLL & 0xff) | value << 8;
    } else {
      regSCROLL = (regSCROLL & 0xff00) | value;
    }
    _scrollWriteUpper = !_scrollWriteUpper;
  }

  // VRAM Address ($2006) >> write x2, 16-bit
  int regADDR;

  // VRAM temporary address, used in PPU
  int regTMPADDR;

  // 0: write PPUADDR upper bits, 1: write lower bits
  bool _addrWriteUpper = true;

  void setPPUADDR(int value) {
    if (_addrWriteUpper) {
      regADDR = (regADDR & 0xff) | value << 8;
    } else {
      regADDR = (regADDR & 0xff00) | value;
    }
    _addrWriteUpper = !_addrWriteUpper;
  }

  // see: https://wiki.nesdev.com/w/index.php/PPUregisters#The_PPUDATA_read_buffer_.28post-fetch.29
  // the first result should be discard when CPU reading PPUDATA
  int _ppuDataBuffer = 0x00;

  // Data ($2007) <> read/write
  // this is the port that CPU read/write data via VRAM.
  int getPPUDATA() {
    int vramData = read(regADDR);
    int value;

    if (regADDR % 0x4000 < 0x3f00) {
      value = _ppuDataBuffer;
      _ppuDataBuffer = vramData; // update data buffer with vram data
    } else {
      // when reading palttes, the buffer data is the mirrored nametable data that would appear "underneath" the palette.
      value = vramData;
      _ppuDataBuffer = read(regADDR - 0x1000);
    }

    regADDR += addrStepSize;
    return value;
  }

  void setPPUDATA(int value) {
    write(regADDR, value);

    regADDR += addrStepSize;
  }

  // OAM DMA ($4014) > write
  void setOAMDMA(int value) {
    int page = value << 8;

    int oamAddr = regOAMADDR;
    for (int i = 0; i < 0xff; i++) {
      _spriteRAM.write(oamAddr + i, bus.cpu.read(page + i));
    }
  }

  int scanline = -1; // start from pre render scanline
  int cycle = 0;
  int frames = 0;
  bool frameCompleted = false;

  bool get isScanLineVisible => scanline >= 0 && scanline <= 239;
  bool get isScanLinePreRender => scanline == -1;
  bool get isCycleVisible => cycle >= 1 && cycle <= 256;

  int _NTByte = 0;
  int _AT4Bit = 0; // lower 2 bits for current tile, upper for next tile
  int _lowBGTile16Bit = 0;
  int _highBGTile16Bit = 0;

  Frame frame = Frame();

  Pos _getXYWhenFetching() {
    int x = cycle - 1, y = scanline;

    // for next scanline
    if (cycle >= 321 && cycle <= 336) {
      x = 0;
      y++;
    }

    return Pos(x, y);
  }

  _renderPixel() {
    int x = cycle - 1, y = scanline;

    int paletteEntry =
        (_AT4Bit & 0x3) << 2 | _highBGTile16Bit.getBit(7 - x % 8) << 1 | _lowBGTile16Bit.getBit(7 - x % 8);

    int paletteNum = read(0x3f00 + paletteEntry);

    frame.setPixel(x, y, paletteNum);
  }

  _fetchNTByte() {
    int addr = baseNTAddress;
    Pos pos = _getXYWhenFetching();

    if (isCycleVisible && isScanLineVisible) {
      addr += (pos.y / 8).floor() * 32 + (pos.x / 8).floor() + 1;
    }

    _NTByte = read(addr);
  }

  _fetchATByte() {
    int addr = baseNTAddress + 0x3c0;
    Pos pos = _getXYWhenFetching();

    addr += (pos.x / 32).floor() + (pos.y / 32).floor() * 8;
    int byte = read(addr);

    bool isLeft = pos.x % 32 < 16;
    bool isTop = pos.y % 32 < 16;

    if (!isTop && !isLeft) {
      _AT4Bit |= (byte >> 6 & 0x3) << 2;
    } else if (!isTop && isLeft) {
      _AT4Bit |= (byte >> 4 & 0x3) << 2;
    } else if (isTop && !isLeft) {
      _AT4Bit |= (byte >> 2 & 0x3) << 2;
    } else {
      _AT4Bit |= (byte & 0x3) << 2;
    }
  }

  _fetchLowBGTileByte() {
    // _NTByte is the number of pattern table
    // so every number skit 16bit(8bit low + 8bit high) * number
    Pos pos = _getXYWhenFetching();

    int addr = backgroundPTAddress + _NTByte * 16 + pos.y % 8 + 8;
    _lowBGTile16Bit |= read(addr) << 8;
  }

  _fetchHighBGTileByte() {
    Pos pos = _getXYWhenFetching();

    int addr = backgroundPTAddress + _NTByte * 16 + pos.y % 8;
    _highBGTile16Bit |= read(addr) << 8;
  }

  _updateBGData() {
    _lowBGTile16Bit >>= 8;
    _highBGTile16Bit >>= 8;
    _AT4Bit >>= 2;
  }

  _evaluateSprites() {}

  clock() {
    // every cycle behaivor is here: https://wiki.nesdev.com/w/index.php/PPU_rendering#Line-by-line_timing

    if (isCycleVisible && isScanLineVisible) {
      _renderPixel();

      if (cycle == 257) {
        _evaluateSprites();
      }
    }

    if (isScanLinePreRender || isScanLineVisible) {
      // fetch background data
      if (cycle.inRange(1, 256) || cycle.inRange(321, 336)) {
        switch (cycle % 8) {
          case 1:
            _fetchNTByte();
            break;
          case 3:
            _fetchATByte();
            break;
          case 5:
            _fetchLowBGTileByte();
            break;
          case 7:
            _fetchHighBGTileByte();
            break;
        }
      }
    }

    if (cycle % 8 == 0) {
      _updateBGData();
    }

    _updateCycles();
  }

  _updateCycles() {
    cycle++;

    // one scanline is completed.
    if (cycle >= CYCLES_PER_SCANLINE) {
      cycle = 0;
      scanline++;
    }

    // OAMADDR is set to 0 during each of ticks 257-320
    if (cycle >= 257 && cycle <= 320) {
      regOAMADDR = 0;
    }

    // start vertical blanking
    if (scanline == 241 && cycle == 1) {
      regSTATUS = regSTATUS.setBit(7, 1);
      // trigger a NMI interrupt
      if (enableNMI) {
        bus.cpu.nmi();
      }
    }

    if (isScanLinePreRender && frames % 2 == 1) {
      scanline++;
      regSTATUS = regSTATUS.setBit(7, 0);
    }

    // one Frame is completed.
    if (scanline >= SCANLINES_PER_FRAME - 1) {
      scanline = -1;
      frames++;
      frameCompleted = true;
      regSTATUS = regSTATUS.setBit(7, 0);
    } else {
      frameCompleted = false;
    }
  }

  void reset() {
    regCTRL = 0x00;
    regMASK = 0x00;
    regSTATUS = regSTATUS.getBit(7) << 7;
    regSCROLL = 0x00;
    _ppuDataBuffer = 0x00;

    _scrollWriteUpper = true;
    _addrWriteUpper = true;
  }

  int read(int address) {
    address &= 0xffff;

    // CHR-ROM or Pattern Tables
    if (address < 0x2000) return bus.cardtridge.readCHR(address);

    // NameTables (RAM)
    if (address < 0x3000) {
      // horizontal mirroring
      // [1][1] --> [0x2000][0x2400]
      // [2][2] --> [0x2800][0x2c00]
      if (bus.cardtridge.mirroring == Mirroring.Horizontal) {
        // mirroring to 0x2000 area
        if (address < 0x2800) {
          return bus.ppuVideoRAM0.read(address % 0x400);
        } else {
          return bus.ppuVideoRAM1.read(address % 0x400);
        }
      }

      // vertical mirroring
      // [1][2] --> [0x2000][0x2400]
      // [1][2] --> [0x2800][0x2c00]
      if (bus.cardtridge.mirroring == Mirroring.Vertical) {
        // mirroring to 0x2000 area
        if (address < 0x2400 || (address >= 0x2800 && address < 0x2c00)) {
          return bus.ppuVideoRAM0.read(address % 0x400);
        } else {
          return bus.ppuVideoRAM1.read(address % 0x400);
        }
      }
    }

    // NameTables Mirrors
    if (address < 0x3f00) return read(0x2000 + address % 0x1000);

    // Palettes
    if (address < 0x3f20) return bus.ppuPalettes.read(address % 0x3f00);

    // Palettes Mirrors
    if (address < 0x4000) return read(0x3f00 + address % 0x20);

    // whole Mirrors
    if (address < 0x10000) return read(address % 0x4000);

    throw ("ppu reading: address ${address.toHex()} is over memory map size.");
  }

  void write(int address, int value) {
    address &= 0xffff;

    // CHR-ROM or Pattern Tables
    if (address < 0x2000) return bus.cardtridge.writeCHR(address, value);

    // NameTables (RAM)
    if (address < 0x3000) {
      // horizontal mirroring
      // [1][1] --> [0x2000][0x2400]
      // [2][2] --> [0x2800][0x2c00]
      if (bus.cardtridge.mirroring == Mirroring.Horizontal) {
        // mirroring to 0x2000 area
        if (address < 0x2800) {
          return bus.ppuVideoRAM0.write(address % 0x400, value);
        } else {
          return bus.ppuVideoRAM1.write(address % 0x400, value);
        }
      }

      // vertical mirroring
      // [1][2] --> [0x2000][0x2400]
      // [1][2] --> [0x2800][0x2c00]
      if (bus.cardtridge.mirroring == Mirroring.Vertical) {
        // mirroring to 0x2000 area
        if (address < 0x2400 || (address >= 0x2800 && address < 0x2c00)) {
          return bus.ppuVideoRAM0.write(address % 0x400, value);
        } else {
          return bus.ppuVideoRAM1.write(address % 0x400, value);
        }
      }
    }

    // NameTables Mirrors
    if (address < 0x3f00) return write(0x2000 + address % 0x1000, value);

    // Palettes
    if (address < 0x3f20) {
      return bus.ppuPalettes.write(address % 0x3f00, value);
    }

    // Palettes Mirrors
    if (address < 0x4000) return write(0x3f00 + (address - 0x3f20) % 0x20, value);

    // whole Mirrors
    if (address < 0x10000) return write(address % 0x4000, value);

    throw ("cpu writing: address ${address.toHex()} is over memory map size.");
  }
}
