class Color {
  const Color(int rgb)
      : this.rgb = rgb,
        this.red = rgb >> 4 & 0xff,
        this.green = rgb >> 2 & 0xff,
        this.blue = rgb & 0xff;

  final int rgb;
  final int red;
  final int green;
  final int blue;
}

const Map<int, Color> _ColorMap = {
  // NES colour palette is in NESDoc page 45.
  0x00: Color(0x757575),
  0x01: Color(0x271b8f),
  0x02: Color(0x0000ab),
  0x03: Color(0x47009f),
  0x04: Color(0x8f0077),
  0x05: Color(0xab0013),
  0x06: Color(0xa70000),
  0x07: Color(0x7f0b00),
  0x08: Color(0x432f00),
  0x09: Color(0x004700),
  0x0a: Color(0x005100),
  0x0b: Color(0x003f17),
  0x0c: Color(0x1b3f5f),
  0x0d: Color(0x000000),
  0x0e: Color(0x000000),
  0x0f: Color(0x000000),

  0x10: Color(0xbcbcbc),
  0x11: Color(0x0073ef),
  0x12: Color(0x233bef),
  0x13: Color(0x8300f3),
  0x14: Color(0xbf00bf),
  0x15: Color(0xe7005b),
  0x16: Color(0xdb2b00),
  0x17: Color(0xcb4f0f),
  0x18: Color(0x8b7300),
  0x19: Color(0x009700),
  0x1a: Color(0x00ab00),
  0x1b: Color(0x00933b),
  0x1c: Color(0x00838b),
  0x1d: Color(0x000000),
  0x1e: Color(0x000000),
  0x1f: Color(0x000000),

  0x20: Color(0xffffff),
  0x21: Color(0x3fbfff),
  0x22: Color(0x5f97ff),
  0x23: Color(0xa78bfd),
  0x24: Color(0xf77bff),
  0x25: Color(0xff77b7),
  0x26: Color(0xff7763),
  0x27: Color(0xff9b3b),
  0x28: Color(0xf3bf3f),
  0x29: Color(0x83d313),
  0x2a: Color(0x4fdf4b),
  0x2b: Color(0x58f898),
  0x2c: Color(0x00ebdb),
  0x2d: Color(0x000000),
  0x2e: Color(0x000000),
  0x2f: Color(0x000000),

  0x30: Color(0xffffff),
  0x31: Color(0xabe7ff),
  0x32: Color(0xc7d7ff),
  0x33: Color(0xd7cbff),
  0x34: Color(0xffc7ff),
  0x35: Color(0xffc7db),
  0x36: Color(0xffbfb3),
  0x37: Color(0xffdbab),
  0x38: Color(0xffe7a3),
  0x39: Color(0xe3ffa3),
  0x3a: Color(0xabf3bf),
  0x3b: Color(0xb3ffcf),
  0x3c: Color(0x9ffff3),
  0x3d: Color(0x000000),
  0x3e: Color(0x000000),
  0x3f: Color(0x000000),
};

Color findColor(int entry) {
  return _ColorMap[entry];
}
