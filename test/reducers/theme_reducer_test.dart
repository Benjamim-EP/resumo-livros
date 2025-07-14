// test/reducers/theme_reducer_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:septima_biblia/design/theme.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/reducers.dart';

void main() {
  group('ThemeReducer', () {
    // Teste 1: Estado Inicial
    test('deve retornar o estado inicial corretamente', () {
      final initialState = ThemeState.initial();

      // ✅ CORREÇÃO: Testamos apenas a opção do enum, que é o que realmente define o estado.
      expect(initialState.activeThemeOption, AppThemeOption.green);
      // Opcional: Podemos testar uma propriedade chave do tema, como a cor primária,
      // para garantir que o ThemeData correto foi carregado, em vez de comparar a instância.
      expect(initialState.activeThemeData.primaryColor,
          AppTheme.greenTheme.primaryColor);
    });

    // Teste 2: Mudar para o tema Septima Escuro
    test(
        'deve alterar o tema para septimaDark ao receber SetThemeAction(septimaDark)',
        () {
      final initialState = ThemeState.initial();
      final action = SetThemeAction(AppThemeOption.septimaDark);

      final newState = themeReducer(initialState, action);

      // ✅ CORREÇÃO: Testamos a opção e uma propriedade chave.
      expect(newState.activeThemeOption, AppThemeOption.septimaDark);
      expect(newState.activeThemeData.primaryColor,
          AppTheme.septimaDarkTheme.primaryColor);
    });

    // Teste 3: Mudar para o tema Septima Claro
    test(
        'deve alterar o tema para septimaLight ao receber SetThemeAction(septimaLight)',
        () {
      final initialState = ThemeState.initial();
      final action = SetThemeAction(AppThemeOption.septimaLight);

      final newState = themeReducer(initialState, action);

      // ✅ CORREÇÃO: Testamos a opção e uma propriedade chave.
      expect(newState.activeThemeOption, AppThemeOption.septimaLight);
      expect(newState.activeThemeData.scaffoldBackgroundColor,
          AppTheme.septimaLightTheme.scaffoldBackgroundColor);
    });

    // Teste 4: Mudar de um tema não-padrão de volta para o padrão (verde)
    test('deve alterar o tema de escuro para verde corretamente', () {
      final darkState = ThemeState(
        activeThemeOption: AppThemeOption.septimaDark,
        activeThemeData: AppTheme.septimaDarkTheme,
      );
      final action = SetThemeAction(AppThemeOption.green);

      final newState = themeReducer(darkState, action);

      // ✅ CORREÇÃO: Testamos a opção e uma propriedade chave.
      expect(newState.activeThemeOption, AppThemeOption.green);
      expect(newState.activeThemeData.primaryColor,
          AppTheme.greenTheme.primaryColor);
    });

    // Teste 5: Lidar com uma ação desconhecida (este já deveria passar, mas o mantemos)
    test('deve retornar o estado atual se uma ação desconhecida for despachada',
        () {
      final initialState = ThemeState.initial();
      final newState = themeReducer(initialState, "UMA_ACAO_QUALQUER");

      // ✅ CORREÇÃO: Comparar instâncias aqui funciona porque nenhuma nova instância foi criada.
      expect(newState, initialState);
      expect(newState.activeThemeOption, AppThemeOption.green);
    });
  });
}
