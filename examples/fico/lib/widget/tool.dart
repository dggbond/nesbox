import 'package:flutter/material.dart';

enum Direction {
  vertical,
  horizontal,
}

class Margin extends StatelessWidget {
  const Margin({
    Key? key,
    required this.direction,
    required this.size,
  }) : super(key: key);

  final Direction direction;
  final double size;

  static vertical(double size) {
    return Margin(direction: Direction.vertical, size: size);
  }

  static horizontal(double size) {
    return Margin(direction: Direction.horizontal, size: size);
  }

  @override
  Widget build(BuildContext context) {
    if (direction == Direction.vertical) {
      return SizedBox(height: size);
    }
    return SizedBox(width: size);
  }
}
