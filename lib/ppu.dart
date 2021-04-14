import 'package:flutter_nes/bus.dart';
import 'package:flutter_nes/util.dart';

class PPU {
  PPU(this.bus);

  BUS bus;

  Int8 regPPUCTRL; // write $2000
  Int8 regPPUMASK; // write $2001
  Int8 regPPUSTATUS; // read $2002
  Int8 regOAMADDR; // write $2003
  Int8 regOAMDATA; // write $2004
  Int8 regPPUSCROLL; // write $2005
  Int8 regPPUADDR; // write $2006
  Int8 regPPUDATA; // read/write $2007
  Int8 regOMADMA; // write $4014

  void powerOn() {
    regPPUCTRL = Int8(0x00);
    regPPUMASK = Int8(0x00);
    regPPUSTATUS = Int8(0xa0); // 1010 0000
    regOAMADDR = Int8(0x00);
    regPPUSCROLL = Int8(0x00);
    regPPUADDR = Int8(0x00);
    regPPUDATA = Int8(0x00);
  }

  void reset() {
    // PPUADDE register is unchange
    regPPUCTRL = Int8(0x00);
    regPPUMASK = Int8(0x00);
    regPPUSTATUS = Int8(regPPUSTATUS.getBit(7) << 7);
    regOAMADDR = Int8(0x00);
    regPPUSCROLL = Int8(0x00);
    regPPUDATA = Int8(0x00);
  }
}
