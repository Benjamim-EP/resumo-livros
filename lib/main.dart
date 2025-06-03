// lib/main.dart
import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/components/bottomNavigationBar/bottomNavigationBar.dart';
// Removido: import 'package:resumo_dos_deuses_flutter/design/theme.dart'; // Será obtido do Redux
import 'package:resumo_dos_deuses_flutter/pages/query_results_page.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart';
import 'package:resumo_dos_deuses_flutter/services/auth_check.dart';
import './services/navigation_service.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';
import './app_initialization.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart'; // Para LoadSavedThemeAction

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInitialization.init();
  // Despacha a ação para carregar o tema salvo ANTES de construir o MaterialApp
  store.dispatch(LoadSavedThemeAction());
  store.dispatch(LoadPendingBibleProgressAction());
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreProvider(
      store: store,
      child: StoreConnector<AppState, ThemeData>(
        converter: (store) => store.state.themeState.activeThemeData,
        builder: (context, activeTheme) {
          return MaterialApp(
            navigatorKey:
                navigatorKey, // Mantém para navegação global se QUALQUER parte do app precisar
            debugShowCheckedModeBanner: false,
            theme: activeTheme,
            // AuthCheck é o único ponto de entrada visual inicial.
            // Ele decidirá internamente se mostra StartScreen, LoginPage ou MainAppScreen.
            home: const AuthCheck(),
            // onGenerateRoute e routes podem ser removidos daqui se AuthCheck
            // e MainAppScreen gerenciarem sua própria navegação interna aninhada.
            // Se você ainda precisa de rotas nomeadas globais acessíveis de qualquer lugar,
            // elas podem permanecer, mas a lógica de AuthCheck precisa ser robusta.
            // Para simplificar o problema atual, vamos remover temporariamente para focar no AuthCheck.
            // onGenerateRoute: NavigationService.generateRoute, // Pode ser re-adicionado depois
          );
        },
      ),
    );
  }
}
