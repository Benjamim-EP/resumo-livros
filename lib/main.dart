// lib/main.dart

import 'package:firebase_in_app_messaging/firebase_in_app_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
// REMOVA O IMPORT DO FLAVOR, NÃO É MAIS NECESSÁRIO AQUI
// import 'package:flutter_flavor/flutter_flavor.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/store.dart'; // Apenas o import do store
import 'package:septima_biblia/services/auth_check.dart';
import 'package:septima_biblia/services/language_provider.dart';
import 'package:septima_biblia/services/library_content_service.dart';
// REMOVA O IMPORT DO PAYMENT SERVICE, NÃO É MAIS NECESSÁRIO AQUI
// import 'package:septima_biblia/services/payment_service.dart';
import './app_initialization.dart';
// REMOVA O IMPORT DO REDUX CORE, NÃO É MAIS NECESSÁRIO AQUI
// import 'package:redux/redux.dart';

const bool kIsIntegrationTest = bool.fromEnvironment('integration_test');
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // NENHUMA LÓGICA DE FLAVOR OU STORE PRECISA ESTAR AQUI AGORA.
  // A variável `store` já foi criada e configurada em `store.dart`.
  if (dotenv.env['STRIPE_PUBLISHABLE_KEY'] != null) {
    Stripe.publishableKey = dotenv.env['STRIPE_PUBLISHABLE_KEY']!;
    await Stripe.instance.applySettings();
    print("Stripe SDK inicializado com sucesso.");
  }

  await initializeDateFormatting('pt_BR');
  await AppInitialization.init();
  FirebaseInAppMessaging.instance.setMessagesSuppressed(false);

  // A variável `store` importada de `store.dart` já está pronta para uso.
  store.dispatch(LoadSavedThemeAction());
  store.dispatch(LoadPendingBibleProgressAction());
  store.dispatch(LoadCrossReferencesAction());

  // Inicia a aplicação Flutter.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  // O construtor não precisa mais receber o store, pois ele é uma variável global.
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreProvider<AppState>(
      store: store, // Usa a instância global do store.
      child: ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: const AuthCheck(),
      ),
    );
  }
}
