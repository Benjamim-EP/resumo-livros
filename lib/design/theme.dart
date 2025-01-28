import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      scaffoldBackgroundColor: const Color(0xFF181A1A), // Cor de fundo
      primaryColor: const Color(0xFFCDE7BE), // Cor principal
      hintColor: const Color(0xFF313333), // Cor secundária
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.white, fontSize: 16), // Texto padrão
        bodyMedium: TextStyle(
            color: Color(0xB3FFFFFF), fontSize: 14), // Texto secundário
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF181A1A),
        foregroundColor: Colors.white, // Cor do texto no AppBar
        elevation: 0, // Sem sombra no AppBar
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: const Color(0xFFCDE7BE), // Cor dos botões
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          foregroundColor: const Color(0xFF181A1A),
          backgroundColor: const Color(0xFFCDE7BE), // Cor do texto do botão
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
