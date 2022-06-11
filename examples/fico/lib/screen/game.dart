import 'package:fico/nesbox_controller.dart';
import 'package:fico/widget/debug_info.dart';
import 'package:fico/widget/frame_canvas.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';

class GameScreen extends HookWidget {
  @override
  Widget build(BuildContext context) {
    final boxController = useNesBoxController();
    final snapshot = useStream(boxController.frameStream);

    useEffect(() {
      boxController.loadGame();
    }, []);

    if (!snapshot.hasData) return SizedBox();

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(flex: 2, child: FrameCanvas(frame: snapshot.data!)),
        if (kDebugMode) Expanded(flex: 1, child: DebugInfoWidget(boxController: boxController)),
      ],
    );
  }
}
