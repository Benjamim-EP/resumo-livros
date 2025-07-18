// lib/services/navigation_service.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/components/bottomNavigationBar/bottomNavigationBar.dart';
import 'package:septima_biblia/pages/community/create_post_page.dart';
import 'package:septima_biblia/pages/community/find_friends_page.dart';
import 'package:septima_biblia/pages/community/friends_page.dart';
import 'package:septima_biblia/pages/community/notifications_page.dart';
import 'package:septima_biblia/pages/community/post_detail_page.dart';
import 'package:septima_biblia/pages/login_page.dart';
import 'package:septima_biblia/pages/query_results_page.dart';
import 'package:septima_biblia/pages/start_screen_page.dart';
import 'package:septima_biblia/pages/signup_page.dart';
import 'package:septima_biblia/pages/user_settings_page.dart';
import 'package:septima_biblia/services/custom_page_route.dart';

class NavigationService {
  static Route<dynamic>? generateRoute(RouteSettings settings) {
    final uri = Uri.parse(settings.name ?? '/');
    if (uri.pathSegments.length == 2 && uri.pathSegments.first == 'post') {
      final postId = uri.pathSegments[1];
      return FadeScalePageRoute(page: PostDetailPage(postId: postId));
    }

    // <<< 2. SUBSTITUA TUDO AQUI >>>
    switch (settings.name) {
      case '/login':
        return FadeScalePageRoute(page: const LoginPage());
      case '/signup':
        return FadeScalePageRoute(page: const SignUpEmailPage());
      case '/mainAppScreen':
        return FadeScalePageRoute(page: const MainAppScreen());
      case '/startScreen':
        return FadeScalePageRoute(page: const StartScreenPage());
      case '/queryResults':
        return FadeScalePageRoute(page: const QueryResultsPage());
      case '/userSettings':
        return FadeScalePageRoute(page: const UserSettingsPage());
      case '/findFriends':
        return FadeScalePageRoute(page: const FindFriendsPage());
      case '/friends':
        return FadeScalePageRoute(page: const FriendsPage());
      case '/notifications':
        return FadeScalePageRoute(page: const NotificationsPage());
      case '/createPost':
        return FadeScalePageRoute(page: const CreatePostPage());
      default:
        // A rota padrão também usa a nova transição
        return FadeScalePageRoute(page: const StartScreenPage());
    }
  }
}
