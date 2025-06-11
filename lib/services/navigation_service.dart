// lib/services/navigation_service.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/components/bottomNavigationBar/bottomNavigationBar.dart';
import 'package:septima_biblia/pages/login_page.dart';
import 'package:septima_biblia/pages/query_results_page.dart';
import 'package:septima_biblia/pages/start_screen_page.dart';
import 'package:septima_biblia/pages/signup_page.dart';
// REMOVIDO: import 'package:septima_biblia/pages/splashViews/finalform_view.dart';
// REMOVIDO: import 'package:septima_biblia/pages/tribe_selection_page.dart';
import 'package:septima_biblia/pages/user_settings_page.dart';

class NavigationService {
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case '/signup':
        return MaterialPageRoute(builder: (_) => const SignUpEmailPage());
      case '/mainAppScreen':
        return MaterialPageRoute(builder: (_) => const MainAppScreen());

      case '/startScreen':
        return MaterialPageRoute(builder: (_) => const StartScreenPage());
      case '/queryResults':
        return MaterialPageRoute(builder: (_) => const QueryResultsPage());
      // CASE '/finalForm' REMOVIDO
      // CASE '/tribeSelection' REMOVIDO
      case '/userSettings':
        return MaterialPageRoute(builder: (_) => const UserSettingsPage());
      default:
        // O default pode ser a StartScreenPage, pois o AuthCheck cuidará do redirecionamento
        // se o usuário já tiver passado por ela ou estiver logado.
        return MaterialPageRoute(builder: (_) => const StartScreenPage());
    }
  }
}
