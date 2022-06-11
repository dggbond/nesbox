import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:nesbox/nesbox.dart';
import 'package:nesbox/frame.dart';

class NesBoxController {
  NesBoxController();

  final NesBox box = NesBox();

  Timer? _frameLoopTimer;

  Completer _gameLoadedCompleter = Completer();

  late Future gameLoaded = _gameLoadedCompleter.future;

  final _frameStreamController = StreamController<Frame>.broadcast();

  Stream<Frame> get frameStream => _frameStreamController.stream;

  loadGame([String gamePath = 'roms/Super_mario_brothers.nes']) async {
    final ByteData gameBytes = await rootBundle.load(gamePath);

    box.loadGame(gameBytes.buffer.asUint8List());
    box.reset();

    _gameLoadedCompleter.complete('loaded');

    runFrameLoop();
  }

  runFrameLoop() {
    _frameLoopTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) async {
      _frameStreamController.sink.add(box.stepFrame());
    });
  }

  pause() {
    _frameLoopTimer?.cancel();
  }

  resume() {
    runFrameLoop();
  }
}

NesBoxController useNesBoxController() {
  final boxContorller = useState(NesBoxController());

  return boxContorller.value;
}
