// Em: lib/main.dart

import 'package:flutter/material.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/services/auth_check.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';
// import 'package:septima_biblia/services/notification_service.dart'; // <<< PODE REMOVER ESTE IMPORT DAQUI
import './app_initialization.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:intl/date_symbol_data_local.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // NENHUMA CHAMADA DE NOTIFICAÇÃO AQUI

  await initializeDateFormatting('pt_BR');

  await AppInitialization.init();
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
      child: AuthCheck(),
    );
  }
}
