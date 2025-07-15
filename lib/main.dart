// Em: lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/auth_check.dart';
import './app_initialization.dart';

// Chave global para navegação a partir de locais sem acesso direto ao BuildContext,
// como middlewares do Redux. Essencial para sua arquitetura.
const bool kIsIntegrationTest = bool.fromEnvironment('integration_test');

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
void main() async {
  // Garante que todos os bindings do Flutter estejam inicializados antes de
  // qualquer código assíncrono ou de inicialização de plugins.
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: ".env");

  // Inicializa a formatação de data e hora para o local 'pt_BR'.
  // Crucial para que datas como "15 de Outubro de 2024" sejam exibidas corretamente.
  await initializeDateFormatting('pt_BR');

  // Inicializa serviços essenciais como o Firebase.
  // AdMob foi removido daqui e a inicialização do Start.io é feita nativamente.
  await AppInitialization.init();

  // Despacha as ações iniciais para carregar dados persistidos no estado do Redux.
  // Isso carrega o tema salvo e qualquer progresso de leitura da Bíblia que
  // estava pendente de sincronização da última sessão.
  store.dispatch(LoadSavedThemeAction());
  store.dispatch(LoadPendingBibleProgressAction());

  // Inicia a aplicação Flutter.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // O StoreProvider disponibiliza o store Redux para toda a árvore de widgets abaixo dele.
    return StoreProvider<AppState>(
      store: store,
      // AuthCheck é o widget raiz que decide se mostra a tela de login/boas-vindas
      // ou a tela principal do aplicativo (MainAppScreen) com base no estado de autenticação.
      child: AuthCheck(),
    );
  }
}
