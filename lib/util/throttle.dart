import 'dart:async';

class Throttle {
  Throttle(this.callback, this.waitMs);

  Function callback;
  int waitMs;

  Timer _timer;

  loop() async {
    var start = DateTime.now();
    callback();
    int msCost = DateTime.now().difference(start).inMilliseconds;

    _timer = Timer(Duration(milliseconds: waitMs - msCost), loop);
  }

  stop() {
    _timer.cancel();
  }
}
