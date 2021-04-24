/* Frame
 * one Frame is two-dimensional int array which int mean the pixel color.
 * so one Frame output a 256x240 two-dimensional array.
*/

typedef FrameForEachPixelCallback(int x, int y, int color);

class Frame {
  Frame() {
    _pixels = List.generate(height, (n) => List.generate(width, (index) => 0xff8f0077));
  }

  List<List<int>> _pixels;

  final int height = 240;
  final int width = 256;

  void setPixel(int x, int y, int color) {
    _pixels[y][x] = color;
  }

  int getPixel(int x, int y) {
    return _pixels[y][x];
  }

  void forEachPixel(FrameForEachPixelCallback fn) {
    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        fn(x, y, _pixels[y][x]);
      }
    }
  }
}
