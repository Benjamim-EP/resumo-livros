import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/components/bottomNavigationBar/bottomNavigationBar.dart';
import 'package:resumo_dos_deuses_flutter/pages/author_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/login_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/explore_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/query_results_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/start_screen_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/signup_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/book_details_page.dart';
import 'package:resumo_dos_deuses_flutter/pages/splashViews/finalform_view.dart';
import 'package:resumo_dos_deuses_flutter/pages/tribe_selection_page.dart';

class NavigationService {
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/login':
        return MaterialPageRoute(builder: (_) => LoginPage());
      case '/signup':
        return MaterialPageRoute(builder: (_) => SignUpEmailPage());
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
      case '/finalForm':
        return MaterialPageRoute(builder: (_) => const FinalFormView());
      case '/tribeSelection':
        final tribos = settings.arguments as Map<String, String>;
        return MaterialPageRoute(
          builder: (_) => TribeSelectionPage(tribos: tribos),
        );
      default:
        return MaterialPageRoute(builder: (_) => LoginPage());
    }
  }
}
