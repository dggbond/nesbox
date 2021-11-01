import 'package:flutter_nes/bus.dart';
import 'package:flutter_nes/cpu.dart' show Interrupt;
import 'package:flutter_nes/memory.dart';
import 'package:flutter_nes/util.dart';
import 'package:flutter_nes/palette.dart';
import 'package:flutter_nes/frame.dart';

const int CYCLES_PER_SCANLINE = 341;
const int SCANLINES_PER_FRAME = 262;

class PPU {
  PPU(this.bus);

  BUS bus;

  // all PPU registers see: https://wiki.nesdev.com/w/index.php/PPU_registers
  // Controller ($2000) > write
  int _regPPUCTRL;
  int get baseNameTableAddress => {
        0: 0x2000,
        1: 0x2400,
        2: 0x2800,
        3: 0x2c00,
      }[_regPPUCTRL & 0x03];
  int get backgroundPTAddress => {
        0: 0x0000,
        1: 0x1000,
      }[_regPPUCTRL.getBit(4)];
  int get addrStepSize => _regPPUCTRL.getBit(3) == 1 ? 32 : 1;
  bool get enableNMI => _regPPUCTRL.getBit(7) == 1;

  void setPPUCTRL(int value) => _regPPUCTRL = value & 0xff;
  int getPPUCTRL() => _regPPUCTRL;

  // Mask ($2001) > write
  int _regPPUMASK;
  bool get greyscaleEnabled => _regPPUMASK.getBit(0) == 1;
  bool get backgroundLeftRenderEnabled => _regPPUMASK.getBit(1) == 1;
  bool get spritesLeftRenderEnabled => _regPPUMASK.getBit(2) == 1;
  bool get backgroundRenderEnabled => _regPPUMASK.getBit(3) == 1;
  bool get spritesRenderEnabled => _regPPUMASK.getBit(4) == 1;

  void setPPUMASK(int value) => _regPPUMASK = value & 0xff;
  int getPPUMASK() => _regPPUMASK;

  // Status ($2002) < read
  int _regPPUSTATUS;
  bool get verticalBlanking => _regPPUSTATUS.getBit(7) == 1;
  bool get spriteHit => _regPPUSTATUS.getBit(6) == 1;
  bool get spriteOverflow => _regPPUSTATUS.getBit(5) == 1;

  int getPPUSTATUS() {
    // Reading the status register will clear bit 7 and address latch for PPUSCROLL and PPUADDR
    int val = _regPPUSTATUS;
    _scrollWriteUpper = true;
    _addrWriteUpper = true;
    _regPPUSTATUS = _regPPUSTATUS.setBit(7, 0);

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
  int _regPPUSCROLL; // 16-bit
  bool _scrollWriteUpper =
      true; // 0: write PPUSCROLL upper bits, 1: write lower bits
  int get scrollX => _regPPUSCROLL & 0xf0 >> 4;
  int get scrollY => _regPPUSCROLL & 0xf;

  void setPPUSCROLL(int value) {
    if (_scrollWriteUpper) {
      _regPPUSCROLL = (_regPPUSCROLL & 0xff) | value << 8;
    } else {
      _regPPUSCROLL = (_regPPUSCROLL & 0xff00) | value;
    }
    _scrollWriteUpper = !_scrollWriteUpper;
  }

  // VRAM Address ($2006) >> write x2
  int _regPPUADDR; // 16-bit
  int _regPPUTMPADDR; // VRAM temporary address, used in PPU
  bool _addrWriteUpper =
      true; // 0: write PPUADDR upper bits, 1: write lower bits

  void setPPUADDR(int value) {
    if (_addrWriteUpper) {
      _regPPUADDR = (_regPPUADDR & 0xff) | value << 8;
    } else {
      _regPPUADDR = (_regPPUADDR & 0xff00) | value;
    }
    _addrWriteUpper = !_addrWriteUpper;
  }

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
      value = vramData;
      _ppuDataBuffer = bus.ppuRead(_regPPUADDR - 0x1000);
    }

    _regPPUADDR += addrStepSize;
    return value;
  }

  void setPPUDATA(int value) {
    debugLog("set PPU data, ${_regPPUADDR.toHex()}: ${value.toHex(2)} ");
    bus.ppuWrite(_regPPUADDR, value);

    _regPPUADDR += addrStepSize;
  }

  // OAM DMA ($4014) > write
  void setOAMDMA(int value) {
    int page = value << 8;

    int oamAddr = _regOAMADDR;
    for (int i = 0; i < 0xff; i++) {
      _spriteRAM.write(oamAddr + i, bus.cpuRead(page + i));
    }
  }

  int scanLine = 0;
  int cycle = 0;
  int frames = 0;

  bool get isScanLineVisible => scanLine >= 0 && scanLine < 240;
  bool get isScanLinePreRender => scanLine == SCANLINES_PER_FRAME - 1;
  bool get isCycleVisible => cycle >= 1 && cycle <= 256;

  // background data rendering now
  int _nameTableByte = 0;
  int _attributeTableByte = 0;
  int _bgTile = 0; // 16-bit tile data

  // background data for next rendering
  int _nextNameTableByte = 0;
  int _nextAttributeTableByte = 0;
  int _nextBgTile = 0;

  // frame info
  Frame frame = Frame();

  _renderPixel() {
    int x = cycle - 1, y = scanLine;
    // this is background render
    int paletteEntry =
        _bgTile.getBit(7 - x % 8) | _bgTile.getBit(15 - x % 8) << 1;
    frame.setPixel(x, y, NES_SYS_PALETTES[paletteEntry]);
    // @TODO sprites render
  }

  _fetchNTByte() {
    int addr = baseNameTableAddress +
        (cycle / 8).floor() +
        (scanLine / 8).floor() * 32;
    _nextNameTableByte = bus.ppuRead(addr);
    debugLog(
        "PPU fetch name table byte: ${_nameTableByte.toHex(2)} from ${addr.toHex()}");
  }

  _fetchATByte() {
    // @TODO
  }

  _fetchLowBGTileByte() {
    int addr = backgroundPTAddress + _nextNameTableByte * 16 + scanLine % 8;
    _nextBgTile = (_nextBgTile & 0xff00) | bus.ppuRead(addr);
  }

  _fetchHighBGTileByte() {
    int addr = backgroundPTAddress + _nextNameTableByte * 16 + scanLine % 8;
    _nextBgTile = (_nextBgTile & 0x00ff) | bus.ppuRead(addr + 8) << 8;
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
      if (cycle >= 1 && cycle <= 256) {
        switch (cycle % 8) {
          case 1:
            // set next data
            _nameTableByte = _nextNameTableByte;
            _attributeTableByte = _nextAttributeTableByte;
            _bgTile = _nextBgTile;

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

    _updateCycles();
  }

  _updateCycles() {
    cycle++;

    // one scanline is completed.
    if (cycle >= CYCLES_PER_SCANLINE) {
      cycle = 0;
      scanLine++;
    }

    // OAMADDR is set to 0 during each of ticks 257-320
    if (cycle >= 257 && cycle <= 320) {
      _regOAMADDR = 0;
    }

    // start vertical blanking
    if (scanLine == 241 && cycle == 1) {
      _regPPUSTATUS = _regPPUSTATUS.setBit(7, 1);
      // trigger a NMI interrupt
      if (enableNMI) {
        bus.cpu.interrupt = Interrupt.NMI;
      }
    }

    if (isScanLinePreRender && frames % 2 == 1) {
      scanLine++;
      _regPPUSTATUS = _regPPUSTATUS.setBit(7, 0);
    }

    // one Frame is completed.
    if (scanLine >= SCANLINES_PER_FRAME) {
      scanLine = 0;
      frames++;
      _regPPUSTATUS = _regPPUSTATUS.setBit(7, 0);
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

    _scrollWriteUpper = true;
    _addrWriteUpper = true;
  }
}
