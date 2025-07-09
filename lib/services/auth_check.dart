// Em: lib/services/auth_check.dart

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:septima_biblia/design/theme.dart';
import 'package:septima_biblia/pages/start_screen_page.dart';
import 'package:septima_biblia/pages/login_page.dart';
import 'package:septima_biblia/pages/signup_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';
import 'package:septima_biblia/components/bottomNavigationBar/bottomNavigationBar.dart';
import 'package:septima_biblia/services/navigation_service.dart';
import 'package:septima_biblia/main.dart'; // Para o navigatorKey
import 'package:flutter_localizations/flutter_localizations.dart';

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    return StoreConnector<AppState, _ViewModel>(
      converter: (store) => _ViewModel.fromStore(store),
      onInit: (store) {
        // O listener continua sendo a ponte crucial entre o Firebase e o Redux.
        FirebaseAuth.instance.authStateChanges().listen((user) {
          if (user != null) {
            // A condição !isLoggedIn previne que o _processUserLogin seja chamado
            // múltiplas vezes se o token do usuário for atualizado em segundo plano.
            if (!store.state.userState.isLoggedIn) {
              _processUserLogin(store, user);
            }
          } else {
            // Se o usuário do Firebase for nulo, garante que o estado do Redux reflita isso.
            if (store.state.userState.isLoggedIn ||
                store.state.userState.isGuestUser) {
              store.dispatch(UserLoggedOutAction());
            }
          }
        });
      },
      builder: (context, vm) {
        // Se o estado Redux diz que o usuário está logado ou é convidado...
        if (vm.isLoggedIn || vm.isGuest) {
          // ...renderizamos o MaterialApp principal.
          return MaterialApp(
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            theme: vm.theme,
            locale: const Locale('pt', 'BR'),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [
              Locale('pt', 'BR'),
            ],
            home: const MainAppScreen(),
            onGenerateRoute: NavigationService.generateRoute,
          );
        }

        // Se o usuário NÃO está logado no Redux, mostramos o fluxo de autenticação.
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.greenTheme,
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const [
            Locale('pt', 'BR'),
          ],
          home: StreamBuilder<User?>(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              // Enquanto o Firebase verifica o estado de autenticação...
              if (snapshot.connectionState == ConnectionState.waiting) {
                // ...mostramos um loader.
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              // Se o Firebase já tem um usuário (ex: login recente, app reiniciado)...
              if (snapshot.hasData) {
                // ...mostramos um loader. O onInit já chamou _processUserLogin
                // e logo o estado Redux (vm.isLoggedIn) será true, trocando para o MaterialApp principal.
                return const Scaffold(
                    body: Center(child: CircularProgressIndicator()));
              }
              // Se não há usuário no Firebase, mostramos a tela inicial para o usuário decidir.
              return const StartScreenPage();
            },
          ),
          onGenerateRoute: (settings) {
            switch (settings.name) {
              case '/login':
                return MaterialPageRoute(builder: (_) => const LoginPage());
              case '/signup':
                return MaterialPageRoute(
                    builder: (_) => const SignUpEmailPage());
              default:
                return MaterialPageRoute(
                    builder: (_) => const StartScreenPage());
            }
          },
        );
      },
    );
  }

  Future<void> _processUserLogin(Store<AppState> store, User user) async {
    print("AuthCheck: Iniciando processamento de login para ${user.uid}");

    // 1. Despacha a ação de login para atualizar o estado básico da UI
    store.dispatch(UserLoggedInAction(
      userId: user.uid,
      email: user.email ?? '',
      nome: user.displayName ?? 'Usuário',
    ));

    // 2. Referência ao documento do usuário no Firestore
    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    try {
      final docSnapshot = await userDocRef.get();
      Map<String, dynamic> userData;

      // 3. Verifica se é um novo usuário ou um usuário existente
      if (!docSnapshot.exists) {
        // --- LÓGICA PARA NOVOS USUÁRIOS ---
        print(
            "AuthCheck: Novo usuário detectado. Criando documentos no Firestore...");
        final initialName =
            user.displayName ?? user.email?.split('@')[0] ?? 'Novo Usuário';
        // Garante que o nome no Firebase Auth esteja sincronizado
        if (user.displayName == null || user.displayName!.isEmpty) {
          await user.updateDisplayName(initialName);
        }

        // Prepara os dados iniciais para o documento 'users'
        final newUserFirestoreData = {
          'userId': user.uid,
          'nome': initialName,
          'email': user.email ?? '',
          'photoURL': user.photoURL ?? '',
          'dataCadastro': FieldValue.serverTimestamp(),
          'selos': 10,
          'descrição': "Bem-vindo(a) ao Septima!",
          'topicSaves': {},
          'userCoins': 100,
          'lastRewardedAdWatchTime': null,
          'rewardedAdsWatchedToday': 0,
          'stripeCustomerId': null,
          'subscriptionStatus': 'inactive',
          'subscriptionEndDate': null,
          'stripeSubscriptionId': null,
          'activePriceId': null,
          // Os campos de Septima ID (username, discriminator) serão adicionados pela Cloud Function
        };
        await userDocRef.set(newUserFirestoreData);
        userData =
            newUserFirestoreData; // Usa os dados recém-criados para a próxima verificação

        // Cria o documento de progresso da Bíblia
        await FirebaseFirestore.instance
            .collection('userBibleProgress')
            .doc(user.uid)
            .set({
          'userId': user.uid,
          'createdAt': FieldValue.serverTimestamp(),
          'rawReadingTime': 0,
          'bibleCompletionCount': 0,
          'currentProgressPercent': 0.0,
          'rankingScore': 0.0,
          'books': {},
        });

        print("AuthCheck: Documentos iniciais criados com sucesso.");
      } else {
        // --- LÓGICA PARA USUÁRIOS EXISTENTES ---
        print(
            "AuthCheck: Usuário existente. Carregando detalhes do Firestore.");
        userData = docSnapshot.data()!;
      }

      // 4. VERIFICA E GERA O SEPTIMA ID (PARA NOVOS E ANTIGOS QUE NÃO TÊM)
      // Esta verificação acontece para todos os usuários que fazem login.
      if (userData['username'] == null || userData['discriminator'] == null) {
        print(
            "AuthCheck: Usuário ${user.uid} não tem Septima ID. Tentando gerar agora...");
        try {
          final functions =
              FirebaseFunctions.instanceFor(region: "southamerica-east1");
          final callable = functions.httpsCallable('assignSeptimaId');
          await callable.call(); // Chama a função que criamos no backend
          print("AuthCheck: Chamada para assignSeptimaId enviada com sucesso.");
          // Após a chamada, o ideal é recarregar os dados do usuário para pegar o novo ID
          store.dispatch(LoadUserDetailsAction());
        } catch (e) {
          print(
              "AuthCheck: ERRO ao chamar a função para gerar o Septima ID: $e");
          // Não é um erro crítico, o app pode continuar.
          // A próxima vez que o usuário logar, o sistema tentará novamente.
        }
      }

      // 5. Despacha os detalhes do usuário para o estado Redux
      // Se for um usuário novo, despacha os dados iniciais.
      // Se for um usuário existente, despacha os dados lidos do Firestore.
      store.dispatch(UserDetailsLoadedAction(userData));

      // 6. Despacha ações para carregar todos os outros dados associados ao usuário
      print(
          "AuthCheck: Despachando ações para carregar dados de suporte (progresso, notas, etc.).");
      store.dispatch(LoadAllBibleProgressAction());
      store.dispatch(LoadUserNotesAction());
      store.dispatch(LoadUserHighlightsAction());
      store.dispatch(LoadAdLimitDataAction());
      store.dispatch(LoadUserDiariesAction());
      store.dispatch(LoadUserCollectionsAction());
      store.dispatch(LoadUserTagsAction());
      store.dispatch(LoadUserCommentHighlightsAction());
    } catch (e) {
      print(
          "AuthCheck: ERRO GERAL no processamento do login para ${user.uid}: $e");
      // Em caso de erro, podemos deslogar o usuário para evitar um estado inconsistente
      store.dispatch(UserLoggedOutAction());
    } finally {
      print("AuthCheck: Processamento de login concluído para ${user.uid}.");
    }
  }
}

// O ViewModel volta a ser simples, sem a flag de loading
class _ViewModel {
  final bool isLoggedIn;
  final bool isGuest;
  final ThemeData theme;

  _ViewModel(
      {required this.isLoggedIn, required this.isGuest, required this.theme});

  static _ViewModel fromStore(Store<AppState> store) {
    return _ViewModel(
      isLoggedIn: store.state.userState.isLoggedIn,
      isGuest: store.state.userState.isGuestUser,
      theme: store.state.themeState.activeThemeData,
    );
  }
}
