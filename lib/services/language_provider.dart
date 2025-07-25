// lib/services/language_provider.dart

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageProvider with ChangeNotifier {
  Locale? _appLocale;
  static const String _languageCodeKey = 'app_language_code';

  Locale? get appLocale => _appLocale;

  LanguageProvider() {
    // Ao iniciar, carrega a preferência de idioma salva.
    _loadLocale();
  }

  // Carrega o código do idioma do SharedPreferences.
  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final languageCode = prefs.getString(_languageCodeKey);

    if (languageCode != null && languageCode.isNotEmpty) {
      _appLocale = Locale(languageCode);
    } else {
      _appLocale = null; // Se for nulo, o app usará o idioma do sistema.
    }
    // Notifica os ouvintes (como o MaterialApp) que o estado mudou.
    notifyListeners();
  }

  // Salva o novo idioma e notifica a UI para reconstruir.
  Future<void> changeLocale(String languageCode) async {
    final prefs = await SharedPreferences.getInstance();

    if (languageCode.isEmpty) {
      // Se um código vazio for passado, removemos a preferência
      // para que o app volte a usar o idioma do sistema.
      _appLocale = null;
      await prefs.remove(_languageCodeKey);
    } else {
      _appLocale = Locale(languageCode);
      await prefs.setString(_languageCodeKey, languageCode);
    }

    notifyListeners();
  }
}
