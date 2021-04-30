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
  int get addrStepSize => _regPPUCTRL.getBit(3) == 1 ? 32 : 1;
  bool get enableNMI => _regPPUCTRL.getBit(7) == 1;

  void setPPUCTRL(int value) => _regPPUCTRL = value & 0xff;

  // Mask ($2001) > write
  int _regPPUMASK;
  bool get greyscaleEnabled => _regPPUMASK.getBit(0) == 1;
  bool get backgroundLeftRenderEnabled => _regPPUMASK.getBit(1) == 1;
  bool get spritesLeftRenderEnabled => _regPPUMASK.getBit(2) == 1;
  bool get backgroundRenderEnabled => _regPPUMASK.getBit(3) == 1;
  bool get spritesRenderEnabled => _regPPUMASK.getBit(4) == 1;

  void setPPUMASK(int value) => _regPPUMASK = value & 0xff;

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
  bool _scrollWriteUpper = true; // 0: write PPUSCROLL upper bits, 1: write lower bits
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
  bool _addrWriteUpper = true; // 0: write PPUADDR upper bits, 1: write lower bits

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

  int scanLine = -1;
  int cycle = 0;
  int frames = 0;

  bool get isScanLineVisible => scanLine >= 0 && scanLine < 240;
  bool get isScanLineVBlanking => scanLine > 240;
  bool get isCycleVisible => cycle >= 1 && cycle <= 256;

  // stored data for render
  int _nameTableByte = 0;
  int _attribute2Bit = 0;
  int _tile16Bit = 0;

  // frame info
  Frame frame = Frame();

  _renderPixel() {
    int x = cycle - 1, y = scanLine;

    // this is background render
    for (int i = 7; i >= 0; i--) {
      int paletteEntry = _tile16Bit.getBit(i + 8) << 1 | _tile16Bit.getBit(i);
      frame.setPixel(x, y, NES_SYS_PALETTES[paletteEntry]);
    }

    // @TODO sprites render
  }

  _fetchNameTableByte() {
    int addr = 0x2000 + (scanLine / 8).floor() * 32 + (cycle / 8).floor();
    _nameTableByte = bus.ppuRead(addr);
    debugLog("PPU fetch name table byte: ${_nameTableByte.toHex(2)} from ${addr.toHex()}");
  }

  _fetchAttributeByte() {
    int nameTableByteIndex = (scanLine * 32 + (cycle / 8).floor()) % 0x03c0;
    int attributeAddress = 0x23c0 + (nameTableByteIndex / 0x10).floor();
    int attributeByte = bus.ppuRead(attributeAddress);
    int positionNum = ((nameTableByteIndex % 16) / 4).floor();

    debugLog("PPU fetch attr byte: ${attributeByte.toHex(2)} from ${attributeAddress.toHex()}");

    _attribute2Bit = (attributeByte >> positionNum * 2) & 0x0003; // 0b11
  }

  _fetchNameTableTileData() {
    int lowerTileByte = bus.ppuRead(_nameTableByte);
    int upperTileByte = bus.ppuRead(_nameTableByte + 0x08);

    _tile16Bit = upperTileByte << 8 | lowerTileByte;
    debugLog("PPU fetch tile byte: ${upperTileByte.toHex(2)}${lowerTileByte.toHex(2)}");
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

    // one scanline is completed.
    if (cycle > CYCLES_PER_SCANLINE) {
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

    if (scanLine == SCANLINES_PER_FRAME - 1 && frames % 2 == 1) {
      scanLine = -1;
      frames++;
      _regPPUSTATUS = _regPPUSTATUS.setBit(7, 0);
    }

    // one Frame is completed.
    if (scanLine > SCANLINES_PER_FRAME) {
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
