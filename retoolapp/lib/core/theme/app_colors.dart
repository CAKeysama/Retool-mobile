import 'package:flutter/material.dart';

class AppColors {
  // Paleta Principal do Sistema
  static const Color red00 = Color(0xFFE40D2C);
  static const Color red01 = Color(0xFF8C1A17);
  static const Color red02 = Color(0xFFFF798D);
  static const Color red03 = Color(0xFFFCC4CC);
  static const Color gray00 = Color(0xFF4A4A4A);
  static const Color gray01 = Color(0xFF808080);
  static const Color gray02 = Color(0xFFD6D6D6);
  static const Color gray03 = Color(0xFFE8E7E7);
  static const Color black00 = Color(0xFF000000);
  static const Color black01 = Color(0xFF2F2F2F);
  static const Color white00 = Color(0xFFFFFFFE);

  // Mapeamento Semântico
  static const Color primary = red00;
  static const Color textTitle = red00;
  static const Color textBody = gray00;
  static const Color textDark = black01;
  static const Color surfaceBg = white00;
  static const Color border = gray02;
  static const Color hover = gray03;

  // Background Gradient
  static const List<Color> bgGradient = [
    Color(0xFFFFFFFF),
    Color(0xFFFDFDFD),
    Color(0xFFF8F8F8),
  ];
}
