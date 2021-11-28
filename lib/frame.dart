import 'dart:typed_data';
import 'palette.dart';

/* Frame
 * one Frame is and int8 array, every pixel takes 4 element as R G B A.
*/
class Frame {
  Frame() {
    pixels = Uint8List(height * width * 4);
  }

  Uint8List pixels;

  final int height = 240;
  final int width = 256;

  void setPixel(int x, int y, int entry) {
    int color = NES_SYS_PALETTES[entry];
    int index = (y * width + x) * 4;

    pixels[index] = color >> 16 & 0xff;
    pixels[index + 1] = color >> 8 & 0xff;
    pixels[index + 2] = color & 0xff;
    pixels[index + 3] = 0xff;
  }
}
