// lib/design/theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  // Cores da Marca "Septima"
  static const Color septimaCoralDark = Color(0xFFE3543E);
  static const Color septimaCoralIntense = Color(0xFFC3331D);
  static const Color septimaBordoDark = Color(0xFF63190E);
  static const Color septimaSalmonLight = Color(0xFFEB7C61);
  static const Color septimaGraphiteDarkBg =
      Color(0xFF1D1A1A); // Fundo principal para tema escuro Septima
  static const Color septimaGraphiteSurface =
      Color(0xFF232538); // Cor de superfície para cards no tema escuro Septima
  static const Color septimaBlack = Color(0xFF000000);
  static const Color septimaWhite = Color(0xFFFFFFFF);
  static const Color septimaGreyText =
      Color(0xFFB0B0B0); // Um cinza claro para texto secundário no escuro

  // Cores do Tema Verde Original (Green Theme)
  static const Color greenThemeBackground = Color(0xFF181A1A);
  static const Color greenThemePrimary = Color(0xFFCDE7BE);
  static const Color greenThemeSecondary =
      Color(0xFF313333); // Usado para cards, etc.
  static const Color greenThemeTextPrimary = Colors.white;
  static const Color greenThemeTextSecondary =
      Color(0xB3FFFFFF); // White com opacidade

  // Nomes das Famílias de Fontes (para consistência)
  static const String fontLogo = 'ASTRO867';
  static const String fontPrimary =
      'Inter'; // Exemplo de fonte primária para corpo de texto
  static const String fontSecondary = 'Poppins'; // Exemplo de fonte secundária

  // --- TEMA VERDE (ORIGINAL) ---
  static ThemeData get greenTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: fontPrimary, // Fonte padrão para o tema verde
      scaffoldBackgroundColor: greenThemeBackground,
      primaryColor: greenThemePrimary,
      hintColor: greenThemeSecondary, // Cor de destaque secundária
      colorScheme: const ColorScheme.dark(
        primary: greenThemePrimary,
        secondary: greenThemeSecondary,
        surface: greenThemeSecondary,
        error: Colors.redAccent,
        onPrimary:
            greenThemeBackground, // Texto sobre a cor primária (verde claro)
        onSecondary: greenThemeTextPrimary,
        onSurface: greenThemeTextPrimary,
        onError: greenThemeTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: greenThemeBackground,
        foregroundColor: greenThemeTextPrimary,
        elevation: 0,
        titleTextStyle: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 20,
            color: greenThemeTextPrimary,
            fontWeight: FontWeight.w600),
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: greenThemePrimary),
        displayMedium: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: greenThemePrimary),
        headlineMedium: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: greenThemeTextPrimary),
        titleLarge: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: greenThemeTextPrimary),
        bodyLarge: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 16,
            color: greenThemeTextPrimary),
        bodyMedium: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 14,
            color: greenThemeTextSecondary),
        labelLarge: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: greenThemeBackground), // Para botões
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: greenThemePrimary,
          foregroundColor: greenThemeBackground,
          textStyle: const TextStyle(
              fontFamily: fontPrimary, fontWeight: FontWeight.w600),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: greenThemePrimary,
        textStyle: const TextStyle(
            fontFamily: fontPrimary, fontWeight: FontWeight.w500),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: greenThemeSecondary.withOpacity(0.5),
        hintStyle: TextStyle(color: greenThemeTextSecondary.withOpacity(0.7)),
        labelStyle: const TextStyle(color: greenThemeTextSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: greenThemePrimary, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: greenThemeSecondary, width: 1),
        ),
      ),
      cardTheme: CardTheme(
        color: greenThemeSecondary,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: greenThemeBackground, // Ou um pouco mais escuro
        selectedItemColor: greenThemePrimary,
        unselectedItemColor: greenThemeTextSecondary,
        type: BottomNavigationBarType.fixed,
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: greenThemePrimary,
        unselectedLabelColor: greenThemeTextSecondary,
        indicatorColor: greenThemePrimary,
      ),
      dividerColor: greenThemeTextSecondary.withOpacity(0.3),
      dialogBackgroundColor: greenThemeSecondary,
    );
  }

  // --- TEMA SEPTIMA ESCURO ---
  static ThemeData get septimaDarkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: fontLogo, // Fonte principal da logo
      scaffoldBackgroundColor: septimaGraphiteDarkBg,
      primaryColor: septimaCoralIntense,
      hintColor: septimaCoralDark, // Para destaques secundários
      colorScheme: ColorScheme.dark(
        primary: septimaCoralIntense,
        secondary: septimaCoralDark,
        surface: septimaGraphiteSurface,
        error: Colors.redAccent.shade100,
        onPrimary: septimaWhite,
        onSecondary: septimaWhite,
        onSurface: septimaWhite,
        onError: septimaBlack,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: septimaGraphiteDarkBg,
        foregroundColor: septimaWhite,
        elevation: 0,
        titleTextStyle: TextStyle(
            fontFamily: fontLogo,
            fontSize: 22,
            color: septimaWhite,
            fontWeight: FontWeight.normal),
      ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(
            fontFamily: fontLogo,
            fontSize: 34,
            color: septimaSalmonLight,
            fontWeight: FontWeight.normal),
        displayMedium: const TextStyle(
            fontFamily: fontLogo,
            fontSize: 28,
            color: septimaSalmonLight,
            fontWeight: FontWeight.normal),
        displaySmall: const TextStyle(
            fontFamily: fontLogo,
            fontSize: 24,
            color: septimaSalmonLight,
            fontWeight: FontWeight.normal),
        headlineMedium: const TextStyle(
            fontFamily: fontLogo,
            fontSize: 22,
            color: septimaWhite,
            fontWeight: FontWeight.normal),
        headlineSmall: const TextStyle(
            fontFamily: fontSecondary,
            fontSize: 20,
            color: septimaWhite,
            fontWeight: FontWeight.w600), // Usando Poppins para subtítulos
        titleLarge: const TextStyle(
            fontFamily: fontLogo,
            fontSize: 18,
            color: septimaWhite,
            fontWeight: FontWeight.normal),
        bodyLarge: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 16,
            color: septimaWhite.withOpacity(0.9),
            height: 1.5),
        bodyMedium: const TextStyle(
            fontFamily: fontPrimary,
            fontSize: 14,
            color: septimaGreyText,
            height: 1.4),
        labelLarge: const TextStyle(
            fontFamily: fontLogo,
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: septimaWhite), // Para botões
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: septimaCoralIntense,
          foregroundColor: septimaWhite,
          textStyle: const TextStyle(
              fontFamily: fontLogo,
              fontSize: 16,
              fontWeight: FontWeight.normal),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: septimaSalmonLight,
        textStyle: const TextStyle(
            fontFamily: fontPrimary, fontWeight: FontWeight.w500),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: septimaGraphiteSurface.withOpacity(0.7),
        hintStyle: TextStyle(color: septimaGreyText.withOpacity(0.7)),
        labelStyle: const TextStyle(color: septimaGreyText),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: septimaCoralDark, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: septimaGraphiteSurface, width: 1),
        ),
      ),
      cardTheme: CardTheme(
        color: septimaGraphiteSurface,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: septimaBlack,
        selectedItemColor: septimaCoralIntense,
        unselectedItemColor: septimaGreyText,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            TextStyle(fontFamily: fontPrimary, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontFamily: fontPrimary),
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: septimaCoralIntense,
        unselectedLabelColor: septimaGreyText,
        indicatorColor: septimaCoralIntense,
        labelStyle:
            TextStyle(fontFamily: fontPrimary, fontWeight: FontWeight.w500),
        unselectedLabelStyle: TextStyle(fontFamily: fontPrimary),
      ),
      dividerColor: septimaGreyText.withOpacity(0.2),
      dialogBackgroundColor: septimaGraphiteSurface,
    );
  }

  // --- TEMA SEPTIMA CLARO ("POSITIVO") ---
  static ThemeData get septimaLightTheme {
    return ThemeData(
      brightness: Brightness.light,
      fontFamily: fontLogo,
      scaffoldBackgroundColor: Colors
          .grey.shade50, // Um branco levemente acinzentado para não cansar
      primaryColor: septimaCoralIntense,
      hintColor: septimaSalmonLight,
      colorScheme: ColorScheme.light(
        primary: septimaCoralIntense,
        secondary: septimaCoralDark,
        surface: septimaWhite,
        error: Colors.red.shade700,
        onPrimary: septimaWhite,
        onSecondary: septimaWhite,
        onSurface: septimaBlack,
        onError: septimaWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: septimaCoralDark, // AppBar com cor da marca
        foregroundColor: septimaWhite,
        elevation: 1,
        titleTextStyle: TextStyle(
            fontFamily: fontLogo,
            fontSize: 22,
            color: septimaWhite,
            fontWeight: FontWeight.normal),
      ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(
            fontFamily: fontLogo,
            fontSize: 34,
            color: septimaBordoDark,
            fontWeight: FontWeight.normal),
        displayMedium: const TextStyle(
            fontFamily: fontLogo,
            fontSize: 28,
            color: septimaBordoDark,
            fontWeight: FontWeight.normal),
        displaySmall: const TextStyle(
            fontFamily: fontLogo,
            fontSize: 24,
            color: septimaBordoDark,
            fontWeight: FontWeight.normal),
        headlineMedium: const TextStyle(
            fontFamily: fontLogo,
            fontSize: 22,
            color: septimaGraphiteDarkBg,
            fontWeight: FontWeight.normal),
        headlineSmall: const TextStyle(
            fontFamily: fontSecondary,
            fontSize: 20,
            color: septimaGraphiteDarkBg,
            fontWeight: FontWeight.w600),
        titleLarge: const TextStyle(
            fontFamily: fontLogo,
            fontSize: 18,
            color: septimaGraphiteDarkBg,
            fontWeight: FontWeight.normal),
        bodyLarge: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 16,
            color: septimaGraphiteDarkBg.withOpacity(0.87),
            height: 1.5),
        bodyMedium: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 14,
            color: septimaGraphiteDarkBg.withOpacity(0.70),
            height: 1.4),
        labelLarge: const TextStyle(
            fontFamily: fontLogo,
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: septimaWhite), // Para botões
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: septimaCoralIntense,
          foregroundColor: septimaWhite,
          textStyle: const TextStyle(
              fontFamily: fontLogo,
              fontSize: 16,
              fontWeight: FontWeight.normal),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: septimaCoralIntense,
        textStyle: const TextStyle(
            fontFamily: fontPrimary, fontWeight: FontWeight.w500),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade200,
        hintStyle: TextStyle(color: Colors.grey.shade500),
        labelStyle: TextStyle(color: Colors.grey.shade700),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: septimaCoralIntense, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      cardTheme: CardTheme(
        color: septimaWhite,
        elevation: 2,
        shadowColor: Colors.grey.shade300,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: septimaWhite,
        selectedItemColor: septimaCoralIntense,
        unselectedItemColor: Colors.grey.shade600,
        type: BottomNavigationBarType.fixed,
        elevation: 2,
        selectedLabelStyle: const TextStyle(
            fontFamily: fontPrimary, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontFamily: fontPrimary),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: septimaCoralIntense,
        unselectedLabelColor: Colors.grey.shade600,
        indicatorColor: septimaCoralIntense,
        labelStyle: const TextStyle(
            fontFamily: fontPrimary, fontWeight: FontWeight.w500),
        unselectedLabelStyle: const TextStyle(fontFamily: fontPrimary),
      ),
      dividerColor: Colors.grey.shade300,
      dialogBackgroundColor: septimaWhite,
    );
  }
}
