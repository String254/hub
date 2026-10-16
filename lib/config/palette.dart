import 'package:flutter/material.dart';

class Palette {
  static const Color scaffold = Color(0xFF9EBBB2);
  static const Color nestBlue = Color(0xFF0757AC);
  static const Color theme = Color(0xFF009688);
  static const Color gradientStartColor = Color(0xffe6fdf9);
  static const Color gradientEndColor = Color(0xffaffff1);
  static const Color primaryColor = Color(0xFF47D5C1);
  static LinearGradient background = const LinearGradient(
      colors: [
        gradientStartColor,
        gradientEndColor
      ],
      begin: FractionalOffset(0.2, 0.2),
      end: FractionalOffset(1.0, 1.0),
      stops: [0.0, 1.0],
      tileMode: TileMode.clamp);

}
const primaryColor = Color(0xFF47D5C1);
const canvasColor = Color(0xFF049B96);
const scaffoldBackgroundColor = Color(0xFF19F1B0);
const accentCanvasColor = Color(0xFF5EA896);
const white = Colors.white;
final actionColor = const Color(0xFF05F3C8).withOpacity(0.6);
final divider = Divider(color: white.withOpacity(0.3), height: 1);