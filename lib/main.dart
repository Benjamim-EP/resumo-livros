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
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreProvider(
      store: store,
      child: StoreConnector<AppState, ThemeData>(
        // Conecta ao ThemeData ativo
        converter: (store) => store.state.themeState.activeThemeData,
        builder: (context, activeTheme) {
          // `activeTheme` é o ThemeData do estado
          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: activeTheme, // Aplica o tema ativo do Redux
            home: const AuthCheck(),
            onGenerateRoute: NavigationService.generateRoute,
            routes: {
              '/mainAppScreen': (context) => const MainAppScreen(),
              '/queryResults': (context) => const QueryResultsPage(),
            },
          );
        },
      ),
    );
  }
}
