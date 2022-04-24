library nesbox.frame;

import 'dart:typed_data';

/* Frame
 * one Frame is and int8 array, every pixel takes 4 element as R G B A.
*/
class Frame {
  Frame({
    this.width = 256,
    this.height = 240,
  }) {
    pixels = Uint8List(height * width * 4);
  }

  late Uint8List pixels;

  int height;
  int width;

  void setPixel(int x, int y, int color) {
    int index = (y * width + x) * 4;

    pixels[index] = color >> 16 & 0xff;
    pixels[index + 1] = color >> 8 & 0xff;
    pixels[index + 2] = color & 0xff;
    pixels[index + 3] = 0xff;
  }
}
