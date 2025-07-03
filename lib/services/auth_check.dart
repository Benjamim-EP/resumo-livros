// Em: lib/services/auth_check.dart

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
        // O listener é a ponte entre as mudanças de autenticação do Firebase e o estado do Redux.
        // Ele garante que o Redux sempre reflita o status real de autenticação.
        FirebaseAuth.instance.authStateChanges().listen((user) {
          if (user != null) {
            if (!store.state.userState.isLoggedIn &&
                !store.state.userState.isLoadingLogin) {
              // Evita reprocessar durante o login
              _processUserLogin(store, user);
            }
          } else {
            if (store.state.userState.isLoggedIn ||
                store.state.userState.isGuestUser) {
              store.dispatch(UserLoggedOutAction());
            }
          }
        });
      },
      builder: (context, vm) {
        // A decisão de qual tela/app mostrar é baseada 100% no estado do Redux (vm).
        // Isso evita condições de corrida entre o Stream do Firebase e a renderização da UI.
        if (vm.isLoadingLogin) {
          return MaterialApp(
            // Precisa de um MaterialApp para o Scaffold funcionar
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: const Center(
                child: CircularProgressIndicator(),
              ),
            ),
          );
        }

        // Se o usuário está logado ou é um convidado...
        if (vm.isLoggedIn || vm.isGuest) {
          // Mostra o MaterialApp principal do aplicativo, com o tema dinâmico do Redux.
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
        } else {
          // Se não está logado nem é convidado, mostra o MaterialApp de autenticação.
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme
                .greenTheme, // Um tema fixo e leve para as telas de login.
            home:
                const StartScreenPage(), // A tela inicial é a raiz deste fluxo.
            onGenerateRoute: (settings) {
              // Rotas específicas para o fluxo de autenticação.
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
        }
      },
    );
  }

  /// Processa o login do usuário, criando ou carregando seus dados do Firestore
  /// e despachando ações para popular o estado do Redux.
  Future<void> _processUserLogin(Store<AppState> store, User user) async {
    print("AuthCheck: Iniciando processamento para ${user.uid}");

    // 1. Informa ao Redux que o usuário está logado.
    store.dispatch(UserLoggedInAction(
      userId: user.uid,
      email: user.email ?? '',
      nome: user.displayName ?? 'Usuário',
    ));

    // 2. Referência ao documento do usuário no Firestore.
    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userDocRef.get();

    // 3. Verifica se é um novo usuário ou um usuário existente.
    if (!docSnapshot.exists) {
      // 3.1. Se for um novo usuário, cria seu documento no Firestore.
      print("AuthCheck: Novo usuário. Criando documentos...");
      final initialName =
          user.displayName ?? user.email?.split('@')[0] ?? 'Novo Usuário';
      await user.updateDisplayName(initialName);

      final newUserFirestoreData = {
        'userId': user.uid,
        'nome': initialName,
        'email': user.email ?? '',
        'photoURL': user.photoURL ?? '',
        'dataCadastro': FieldValue.serverTimestamp(),
        'Dias': 0,
        'Livros': 0,
        'Tópicos': 0,
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
      };
      await userDocRef.set(newUserFirestoreData);
      store.dispatch(UserDetailsLoadedAction(newUserFirestoreData));

      // Cria o documento de progresso da Bíblia para o novo usuário.
      final commonData = {
        'userId': user.uid,
        'createdAt': FieldValue.serverTimestamp()
      };
      final batch = FirebaseFirestore.instance.batch();
      batch.set(
          FirebaseFirestore.instance
              .collection('userBibleProgress')
              .doc(user.uid),
          {...commonData, 'books': {}});
      await batch.commit();
    } else {
      // 3.2. Se o usuário já existe, carrega seus dados.
      print("AuthCheck: Usuário existente. Carregando detalhes.");
      store.dispatch(UserDetailsLoadedAction(docSnapshot.data()!));
    }

    // 4. Despacha ações para carregar todos os outros dados associados ao usuário.
    print("AuthCheck: Despachando ações para carregar dados adicionais.");
    store.dispatch(LoadAllBibleProgressAction());
    store.dispatch(LoadUserNotesAction());
    store.dispatch(LoadUserHighlightsAction());
    store.dispatch(LoadAdLimitDataAction());
    store.dispatch(LoadUserDiariesAction());
    store.dispatch(LoadUserCollectionsAction());
    store.dispatch(LoadUserTagsAction());

    print("AuthCheck: Processamento de login concluído para ${user.uid}.");
  }
}

/// ViewModel para conectar o AuthCheck ao estado do Redux.
class _ViewModel {
  final bool isLoggedIn;
  final bool isGuest;
  final ThemeData theme;
  final bool isLoadingLogin;

  _ViewModel(
      {required this.isLoggedIn,
      required this.isGuest,
      required this.theme,
      required this.isLoadingLogin});

  static _ViewModel fromStore(Store<AppState> store) {
    return _ViewModel(
      isLoggedIn: store.state.userState.isLoggedIn,
      isGuest: store.state.userState.isGuestUser,
      theme: store.state.themeState.activeThemeData,
      isLoadingLogin: store.state.userState.isLoadingLogin,
    );
  }
}
