import 'dart:typed_data';

import 'bus.dart';
import 'cpu_instructions.dart' show Interrupt;
import 'memory.dart';
import 'util/number.dart';
import 'util/logger.dart';
import 'frame.dart';
import 'palette.dart';

const int CYCLES_PER_SCANLINE = 341;
const int SCANLINES_PER_FRAME = 262;

class PPU {
  PPU(this.bus);

  BUS bus;

  // all PPU registers see: https://wiki.nesdev.com/w/index.php/PPU_registers
  // Controller ($2000) > write
  int _regCTRL;
  int get baseNTAddress => {
        0: 0x2000,
        1: 0x2400,
        2: 0x2800,
        3: 0x2c00,
      }[_regCTRL & 0x03];
  int get baseATAddress => baseNTAddress + 0x3c0;
  int get backgroundPTAddress => {
        0: 0x0000,
        1: 0x1000,
      }[_regCTRL.getBit(4)];
  int get addrStepSize => _regCTRL.getBit(3) == 1 ? 32 : 1;
  bool get enableNMI => _regCTRL.getBit(7) == 1;

  void setPPUCTRL(int value) => _regCTRL = value & 0xff;
  int getPPUCTRL() => _regCTRL;

  // Mask ($2001) > write
  int _regMASK;
  bool get greyscaleEnabled => _regMASK.getBit(0) == 1;
  bool get backgroundLeftRenderEnabled => _regMASK.getBit(1) == 1;
  bool get spritesLeftRenderEnabled => _regMASK.getBit(2) == 1;
  bool get backgroundRenderEnabled => _regMASK.getBit(3) == 1;
  bool get spritesRenderEnabled => _regMASK.getBit(4) == 1;

  void setPPUMASK(int value) => _regMASK = value & 0xff;
  int getPPUMASK() => _regMASK;

  // Status ($2002) < read
  int _regSTATUS;
  bool get verticalBlanking => _regSTATUS.getBit(7) == 1;
  bool get spriteHit => _regSTATUS.getBit(6) == 1;
  bool get spriteOverflow => _regSTATUS.getBit(5) == 1;

  int getPPUSTATUS() {
    // Reading the status register will clear bit 7 and address latch for PPUSCROLL and PPUADDR
    int val = _regSTATUS;
    _scrollWriteUpper = true;
    _addrWriteUpper = true;
    _regSTATUS = _regSTATUS.setBit(7, 0);

    return val;
  }

  // OAM address ($2003) > write
  int _regOAMADDR;

  void setOAMADDR(int value) => _regOAMADDR = value;
  int getOAMADDR() => _regOAMADDR;

  // OAM(SPR-RAM) data ($2004) <> read/write
  // The OAM (Object Attribute Memory) is internal memory inside the PPU that contains a display list of up to 64 sprites,
  // where each sprite's information occupies 4 bytes. So OAM takes 256 bytes
  Memory _spriteRAM = Memory(0xff);

  int getOAMDATA() => _spriteRAM.read(_regOAMADDR);
  void setOAMDATA(int value) => _spriteRAM.write(_regOAMADDR++, value);

  // Scroll ($2005) >> write x2
  // upper byte mean x scroll.
  // lower byte mean y scroll.
  int _regSCROLL; // 16-bit

  // 0: write PPUSCROLL upper bits, 1: write lower bits
  bool _scrollWriteUpper = true;
  int get scrollX => _regSCROLL & 0xf0 >> 4;
  int get scrollY => _regSCROLL & 0xf;

  void setPPUSCROLL(int value) {
    if (_scrollWriteUpper) {
      _regSCROLL = (_regSCROLL & 0xff) | value << 8;
    } else {
      _regSCROLL = (_regSCROLL & 0xff00) | value;
    }
    _scrollWriteUpper = !_scrollWriteUpper;
  }

  // VRAM Address ($2006) >> write x2, 16-bit
  int _regADDR;

  // VRAM temporary address, used in PPU
  int _regTMPADDR;

  // 0: write PPUADDR upper bits, 1: write lower bits
  bool _addrWriteUpper = true;

  void setPPUADDR(int value) {
    if (_addrWriteUpper) {
      _regADDR = (_regADDR & 0xff) | value << 8;
    } else {
      _regADDR = (_regADDR & 0xff00) | value;
    }
    _addrWriteUpper = !_addrWriteUpper;
  }

  // see: https://wiki.nesdev.com/w/index.php/PPU_registers#The_PPUDATA_read_buffer_.28post-fetch.29
  // the first result should be discard when CPU reading PPUDATA
  int _ppuDataBuffer = 0x00;

  // Data ($2007) <> read/write
  // this is the port that CPU read/write data via VRAM.
  int getPPUDATA() {
    int vramData = bus.ppuRead(_regADDR);
    int value;

    if (_regADDR % 0x4000 < 0x3f00) {
      value = _ppuDataBuffer;
      _ppuDataBuffer = vramData; // update data buffer with vram data
    } else {
      // when reading palttes, the buffer data is the mirrored nametable data that would appear "underneath" the palette.
      value = vramData;
      _ppuDataBuffer = bus.ppuRead(_regADDR - 0x1000);
    }

    _regADDR += addrStepSize;
    return value;
  }

  void setPPUDATA(int value) {
    bus.ppuWrite(_regADDR, value);

    _regADDR += addrStepSize;
  }

  // OAM DMA ($4014) > write
  void setOAMDMA(int value) {
    int page = value << 8;

    int oamAddr = _regOAMADDR;
    for (int i = 0; i < 0xff; i++) {
      _spriteRAM.write(oamAddr + i, bus.cpuRead(page + i));
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

  _renderPixel() {
    int x = cycle - 1, y = scanline;
    // this is background render

    int paletteEntry = (_AT4Bit & 0x3) << 2 |
        _highBGTile16Bit.getBit(7 - x % 8) << 1 |
        _lowBGTile16Bit.getBit(7 - x % 8);

    int paletteNum = bus.ppuRead(0x3f00 + paletteEntry);

    frame.setPixel(x, y, paletteNum);
  }

  _fetchNTByte() {
    int addr = baseNTAddress;
    int x = cycle - 1;
    int y = scanline;

    // for next scanline
    if (cycle >= 321 && cycle <= 336) {
      x = 0;
      y += 1;
    }

    if (isCycleVisible && isScanLineVisible) {
      addr += (y / 8).floor() * 32 + (x / 8).floor() + 1;
    }

    _NTByte = bus.ppuRead(addr);
  }

  _fetchATByte() {
    int addr = baseNTAddress + 0x3c0;
    int x = cycle - 1;
    int y = scanline;

    if (cycle >= 321 && cycle <= 336) {
      x = 0;
      y += 1;
    }

    addr += (x / 32).floor() + (y / 32).floor() * 8;
    int byte = bus.ppuRead(addr);

    bool isLeft = x % 32 < 16;
    bool isTop = y % 32 < 16;

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

    int y = scanline;
    if (cycle >= 321 && cycle <= 336) {
      y += 1;
    }

    int addr = backgroundPTAddress + _NTByte * 16 + y % 8 + 8;
    _lowBGTile16Bit |= bus.ppuRead(addr) << 8;
  }

  _fetchHighBGTileByte() {
    int y = scanline;
    if (cycle >= 321 && cycle <= 336) {
      y += 1;
    }

    int addr = backgroundPTAddress + _NTByte * 16 + y % 8;
    _highBGTile16Bit |= bus.ppuRead(addr) << 8;
  }

  _updateBGData() {
    _lowBGTile16Bit >>= 8;
    _highBGTile16Bit >>= 8;
    _AT4Bit >>= 2;
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
      _regOAMADDR = 0;
    }

    // start vertical blanking
    if (scanline == 241 && cycle == 1) {
      _regSTATUS = _regSTATUS.setBit(7, 1);
      // trigger a NMI interrupt
      if (enableNMI) {
        bus.cpu.interrupt = Interrupt.NMI;
      }
    }

    if (isScanLinePreRender && frames % 2 == 1) {
      scanline++;
      _regSTATUS = _regSTATUS.setBit(7, 0);
    }

    // one Frame is completed.
    if (scanline >= SCANLINES_PER_FRAME - 1) {
      scanline = -1;
      frames++;
      frameCompleted = true;
      _regSTATUS = _regSTATUS.setBit(7, 0);
    } else {
      frameCompleted = false;
    }
  }

  void powerOn() {
    _regCTRL = 0x00;
    _regMASK = 0x00;
    _regSTATUS = 0x00;
    _regOAMADDR = 0x00;
    _regSCROLL = 0x00;
    _regADDR = 0x00;
  }

  void reset() {
    _regCTRL = 0x00;
    _regMASK = 0x00;
    _regSTATUS = _regSTATUS.getBit(7) << 7;
    _regSCROLL = 0x00;
    _ppuDataBuffer = 0x00;

    _scrollWriteUpper = true;
    _addrWriteUpper = true;
  }
}
