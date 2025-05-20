// lib/services/navigation_service.dart
import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/components/bottomNavigationBar/bottomNavigationBar.dart';
import 'package:resumo_dos_deuses_flutter/pages/author_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/login_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/query_results_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/start_screen_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/signup_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
// REMOVIDO: import 'package:resumo_dos_deuses_flutter/pages/splashViews/finalform_view.dart';
// REMOVIDO: import 'package:resumo_dos_deuses_flutter/pages/tribe_selection_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/user_settings_page.dart';

class NavigationService {
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(builder: (_) => const LoginPage());
      case '/signup':
        return MaterialPageRoute(builder: (_) => const SignUpEmailPage());
      case '/mainAppScreen':
        return MaterialPageRoute(builder: (_) => const MainAppScreen());
      case '/bookDetails':
        final bookId = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => BookDetailsPage(bookId: bookId),
        );
      case '/authorPage':
        final authorId = settings.arguments as String?;
        if (authorId == null) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('ID do autor não fornecido')),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => AuthorPage(authorId: authorId),
        );
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
