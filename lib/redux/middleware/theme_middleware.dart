// lib/redux/middleware/theme_middleware.dart
import 'package:redux/redux.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/reducers.dart'; // Para AppThemeOption
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

const String _themePreferenceKey = 'app_theme_preference';

List<Middleware<AppState>> createThemeMiddleware() {
  return [
    TypedMiddleware<AppState, SetThemeAction>(_saveThemePreference).call,
    TypedMiddleware<AppState, LoadSavedThemeAction>(_loadThemePreference).call,
  ];
}

// Middleware para salvar a preferência de tema
void Function(Store<AppState>, SetThemeAction, NextDispatcher)
    _saveThemePreference =
    (Store<AppState> store, SetThemeAction action, NextDispatcher next) async {
  next(action); // Deixa o reducer atualizar o estado primeiro

  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _themePreferenceKey, action.themeOption.name); // Salva o nome do enum
    print(
        "Middleware: Preferência de tema (${action.themeOption.name}) salva.");
  } catch (e) {
    print("Middleware: Erro ao salvar preferência de tema: $e");
  }
};

// Middleware para carregar a preferência de tema salva
void Function(Store<AppState>, LoadSavedThemeAction, NextDispatcher)
    _loadThemePreference = (Store<AppState> store, LoadSavedThemeAction action,
        NextDispatcher next) async {
  next(action);

  try {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themePreferenceKey);

    if (themeName != null) {
      // Converte o nome salvo de volta para o enum AppThemeOption
      final themeOption = AppThemeOption.values.firstWhere(
        (e) => e.name == themeName,
        orElse: () => AppThemeOption.green, // Padrão se não encontrar
      );
      print(
          "Middleware: Preferência de tema carregada: $themeName -> $themeOption");
      store.dispatch(
          SetThemeAction(themeOption)); // Despacha para atualizar o estado
    } else {
      print(
          "Middleware: Nenhuma preferência de tema salva encontrada. Usando padrão.");
      // O estado inicial já define um tema padrão, então não precisa despachar aqui
      // a menos que você queira forçar o tema padrão se nenhum for encontrado.
      // store.dispatch(SetThemeAction(AppThemeOption.green)); // Opcional
    }
  } catch (e) {
    print("Middleware: Erro ao carregar preferência de tema: $e");
    // Em caso de erro, pode definir um tema padrão
    store.dispatch(SetThemeAction(AppThemeOption.green));
  }
};
