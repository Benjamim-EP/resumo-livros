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
  // static const String fontLogo =
  //     'ASTRO867'; // Pode ser usado para o nome do app ou grandes destaques
  static const String fontPrimary =
      'Inter'; // Fonte principal para corpo de texto e UI geral
  static const String fontSecondary =
      'Poppins'; // Fonte secundária para alguns títulos ou ênfases

  // static const svgtheme = Color.fromARGB(255, 185, 166, 80); // Removido se não usado globalmente ou movido para onde é específico

  // --- TEMA VERDE (ORIGINAL) ---
  static ThemeData get greenTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: fontPrimary, // Fonte padrão para o tema verde
      scaffoldBackgroundColor: greenThemeBackground,
      primaryColor: greenThemePrimary,
      hintColor:
          const Color.fromARGB(255, 51, 51, 49), // Ajustado no seu código
      colorScheme: const ColorScheme.dark(
        primary: greenThemePrimary,
        secondary: greenThemeSecondary,
        surface: greenThemeSecondary,
        error: Colors.redAccent,
        onPrimary: greenThemeBackground,
        onSecondary: greenThemeTextPrimary,
        onSurface: greenThemeTextPrimary,
        onError: greenThemeTextPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: greenThemeBackground,
        foregroundColor: greenThemeTextPrimary,
        elevation: 0,
        titleTextStyle: TextStyle(
            fontFamily: fontPrimary, // Consistente com o tema
            fontSize: 20,
            color: greenThemeTextPrimary,
            fontWeight: FontWeight.w600),
        actionsIconTheme: IconThemeData(
          color: greenThemeTextPrimary,
        ),
      ),
      textTheme: const TextTheme(
        // Usando fontPrimary para consistência
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
            color: greenThemeBackground),
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
        hintStyle: TextStyle(
            color: greenThemeTextSecondary.withOpacity(0.7),
            fontFamily: fontPrimary),
        labelStyle: const TextStyle(
            color: greenThemeTextSecondary, fontFamily: fontPrimary),
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
        backgroundColor: greenThemeBackground,
        selectedItemColor: greenThemePrimary,
        unselectedItemColor: greenThemeTextSecondary,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle:
            TextStyle(fontFamily: fontPrimary), // Adicionado fontFamily
        unselectedLabelStyle:
            TextStyle(fontFamily: fontPrimary), // Adicionado fontFamily
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: greenThemePrimary,
        unselectedLabelColor: greenThemeTextSecondary,
        indicatorColor: greenThemePrimary,
        labelStyle: TextStyle(fontFamily: fontPrimary), // Adicionado fontFamily
        unselectedLabelStyle:
            TextStyle(fontFamily: fontPrimary), // Adicionado fontFamily
      ),
      dividerColor: greenThemeTextSecondary.withOpacity(0.3),
      dialogBackgroundColor: greenThemeSecondary,
    );
  }

// --- TEMA SEPTIMA ESCURO (SEM fontLogo) ---
  static ThemeData get septimaDarkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      fontFamily: fontPrimary,
      scaffoldBackgroundColor: septimaGraphiteDarkBg,
      primaryColor: septimaCoralIntense,
      hintColor: septimaCoralDark,
      colorScheme: ColorScheme.dark(
        primary: septimaCoralIntense,
        secondary: septimaCoralDark,
        surface: septimaGraphiteSurface,
        background: septimaGraphiteDarkBg,
        error: Colors.redAccent.shade100,
        onPrimary: septimaWhite,
        onSecondary: septimaWhite,
        onSurface: septimaWhite,
        onBackground: septimaWhite,
        onError: septimaBlack,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: septimaGraphiteDarkBg,
        foregroundColor: septimaWhite,
        elevation: 0,
        titleTextStyle: TextStyle(
            // <<< MUDANÇA AQUI
            fontFamily: fontSecondary, // Usando Poppins para o título da AppBar
            fontSize: 20, // Tamanho padrão para títulos de AppBar
            color: septimaWhite,
            fontWeight:
                FontWeight.w600), // Headlines/títulos costumam ser mais pesados
        actionsIconTheme: IconThemeData(color: septimaWhite),
      ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(
            // <<< MUDANÇA AQUI
            fontFamily: fontSecondary, // Usando Poppins
            fontSize: 34,
            fontWeight:
                FontWeight.w600, // Títulos de display podem ser mais pesados
            color: septimaSalmonLight,
            letterSpacing: -0.5),
        displayMedium: const TextStyle(
            // <<< MUDANÇA AQUI
            fontFamily: fontSecondary, // Usando Poppins
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: septimaSalmonLight),
        displaySmall: const TextStyle(
            fontFamily: fontSecondary,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: septimaSalmonLight),
        headlineLarge: const TextStyle(
            fontFamily: fontSecondary,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: septimaWhite),
        headlineMedium: const TextStyle(
            fontFamily: fontSecondary,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: septimaWhite),
        headlineSmall: const TextStyle(
            fontFamily: fontSecondary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: septimaWhite),
        titleLarge: const TextStyle(
            fontFamily: fontPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: septimaWhite),
        titleMedium: const TextStyle(
            fontFamily: fontPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: septimaWhite,
            letterSpacing: 0.15),
        titleSmall: const TextStyle(
            fontFamily: fontPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: septimaGreyText,
            letterSpacing: 0.1),
        bodyLarge: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: septimaWhite.withOpacity(0.9),
            height: 1.5,
            letterSpacing: 0.5),
        bodyMedium: const TextStyle(
            fontFamily: fontPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: septimaGreyText,
            height: 1.4,
            letterSpacing: 0.25),
        bodySmall: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: septimaGreyText.withOpacity(0.8),
            letterSpacing: 0.4),
        labelLarge: const TextStyle(
            fontFamily: fontPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: septimaWhite,
            letterSpacing: 0.2),
        labelMedium: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: septimaWhite.withOpacity(0.9),
            letterSpacing: 0.5),
        labelSmall: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: septimaGreyText,
            letterSpacing: 0.5),
      ),
      // ... (elevatedButtonTheme, textButtonTheme, etc., permanecem como na versão anterior,
      //      pois já usavam fontPrimary)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: septimaCoralIntense,
          foregroundColor: septimaWhite,
          textStyle: const TextStyle(
              fontFamily: fontPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: septimaSalmonLight,
        textStyle: const TextStyle(
            fontFamily: fontPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: septimaGraphiteSurface.withOpacity(0.7),
        hintStyle: TextStyle(
            color: septimaGreyText.withOpacity(0.7), fontFamily: fontPrimary),
        labelStyle:
            const TextStyle(color: septimaGreyText, fontFamily: fontPrimary),
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
          borderSide: BorderSide(
              color: septimaGraphiteSurface.withOpacity(0.5), width: 1),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      cardTheme: CardTheme(
        color: septimaGraphiteSurface,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: septimaBlack,
        selectedItemColor: septimaCoralIntense,
        unselectedItemColor: septimaGreyText,
        type: BottomNavigationBarType.fixed,
        selectedLabelStyle: TextStyle(
            fontFamily: fontPrimary, fontWeight: FontWeight.w500, fontSize: 12),
        unselectedLabelStyle: TextStyle(fontFamily: fontPrimary, fontSize: 12),
      ),
      tabBarTheme: const TabBarTheme(
        labelColor: septimaCoralIntense,
        unselectedLabelColor: septimaGreyText,
        indicatorColor: septimaCoralIntense,
        labelStyle: TextStyle(
            fontFamily: fontPrimary, fontWeight: FontWeight.w500, fontSize: 14),
        unselectedLabelStyle: TextStyle(fontFamily: fontPrimary, fontSize: 14),
      ),
      dividerColor: septimaGreyText.withOpacity(0.2),
      dialogBackgroundColor: septimaGraphiteSurface,
    );
  }

  // --- TEMA SEPTIMA CLARO ("POSITIVO") (SEM fontLogo) ---
  static ThemeData get septimaLightTheme {
    return ThemeData(
      brightness: Brightness.light,
      fontFamily: fontPrimary,
      scaffoldBackgroundColor: Colors.grey.shade50,
      primaryColor: septimaCoralIntense,
      hintColor: septimaSalmonLight,
      colorScheme: ColorScheme.light(
        primary: septimaCoralIntense,
        secondary: septimaCoralDark,
        surface: septimaWhite,
        background: Colors.grey.shade50,
        error: Colors.red.shade700,
        onPrimary: septimaWhite,
        onSecondary: septimaWhite,
        onSurface: septimaBlack,
        onBackground: septimaBlack,
        onError: septimaWhite,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: septimaCoralDark,
        foregroundColor: septimaWhite,
        elevation: 1,
        titleTextStyle: TextStyle(
            // <<< MUDANÇA AQUI
            fontFamily: fontSecondary, // Usando Poppins
            fontSize: 20,
            color: septimaWhite,
            fontWeight: FontWeight.w600),
        actionsIconTheme: IconThemeData(color: septimaWhite),
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(
            // <<< MUDANÇA AQUI
            fontFamily: fontSecondary, // Usando Poppins
            fontSize: 34,
            fontWeight: FontWeight.w600,
            color: septimaBordoDark,
            letterSpacing: -0.5),
        displayMedium: TextStyle(
            // <<< MUDANÇA AQUI
            fontFamily: fontSecondary, // Usando Poppins
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: septimaBordoDark),
        displaySmall: TextStyle(
            fontFamily: fontSecondary,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: septimaBordoDark),
        headlineLarge: TextStyle(
            fontFamily: fontSecondary,
            fontSize: 28,
            fontWeight: FontWeight.w600,
            color: septimaGraphiteDarkBg.withOpacity(0.87)),
        headlineMedium: TextStyle(
            fontFamily: fontSecondary,
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: septimaGraphiteDarkBg.withOpacity(0.87)),
        headlineSmall: TextStyle(
            fontFamily: fontSecondary,
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: septimaGraphiteDarkBg.withOpacity(0.87)),
        titleLarge: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: septimaGraphiteDarkBg.withOpacity(0.87)),
        titleMedium: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: septimaGraphiteDarkBg.withOpacity(0.87),
            letterSpacing: 0.15),
        titleSmall: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: septimaGraphiteDarkBg.withOpacity(0.60),
            letterSpacing: 0.1),
        bodyLarge: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: septimaGraphiteDarkBg.withOpacity(0.87),
            height: 1.5,
            letterSpacing: 0.5),
        bodyMedium: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w400,
            color: septimaGraphiteDarkBg.withOpacity(0.70),
            height: 1.4,
            letterSpacing: 0.25),
        bodySmall: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w400,
            color: septimaGraphiteDarkBg.withOpacity(0.60),
            letterSpacing: 0.4),
        labelLarge: const TextStyle(
            fontFamily: fontPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: septimaWhite,
            letterSpacing: 0.2),
        labelMedium: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: septimaGraphiteDarkBg.withOpacity(0.87),
            letterSpacing: 0.5),
        labelSmall: TextStyle(
            fontFamily: fontPrimary,
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: septimaGraphiteDarkBg.withOpacity(0.60),
            letterSpacing: 0.5),
      ),
      // ... (elevatedButtonTheme, textButtonTheme, etc., permanecem como na versão anterior,
      //      pois já usavam fontPrimary)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: septimaCoralIntense,
          foregroundColor: septimaWhite,
          textStyle: const TextStyle(
              fontFamily: fontPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
        foregroundColor: septimaCoralIntense,
        textStyle: const TextStyle(
            fontFamily: fontPrimary,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.2),
      )),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.grey.shade200,
        hintStyle:
            TextStyle(color: Colors.grey.shade500, fontFamily: fontPrimary),
        labelStyle:
            TextStyle(color: Colors.grey.shade700, fontFamily: fontPrimary),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
      cardTheme: CardTheme(
        color: septimaWhite,
        elevation: 1.5,
        shadowColor: Colors.grey.shade200,
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
            fontFamily: fontPrimary, fontWeight: FontWeight.w500, fontSize: 12),
        unselectedLabelStyle:
            const TextStyle(fontFamily: fontPrimary, fontSize: 12),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: septimaCoralIntense,
        unselectedLabelColor: Colors.grey.shade700,
        indicatorColor: septimaCoralIntense,
        labelStyle: const TextStyle(
            fontFamily: fontPrimary, fontWeight: FontWeight.w500, fontSize: 14),
        unselectedLabelStyle:
            const TextStyle(fontFamily: fontPrimary, fontSize: 14),
      ),
      dividerColor: Colors.grey.shade300,
      dialogBackgroundColor: septimaWhite,
    );
  }
}
