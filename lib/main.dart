import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/components/bottomNavigationBar/bottomNavigationBar.dart';
import 'package:resumo_dos_deuses_flutter/design/theme.dart';
import 'package:resumo_dos_deuses_flutter/pages/query_results_page.dart';
import 'package:resumo_dos_deuses_flutter/services/auth_check.dart';
import './services/navigation_service.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';
import './app_initialization.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppInitialization.init(); // Inicialização separada
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StoreProvider(
      store: store,
      child: MaterialApp(
        navigatorKey: navigatorKey,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme, // Utilizar o tema personalizado
        home:
            AuthCheck(), // Gerencia login e redireciona para MainAppScreen ou LoginPage
        onGenerateRoute: NavigationService.generateRoute,
        routes: {
          '/mainAppScreen': (context) => const MainAppScreen(),
          '/queryResults': (context) => const QueryResultsPage(),
        },
      ),
    );
  }
}
