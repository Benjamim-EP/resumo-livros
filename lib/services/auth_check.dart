// Em: lib/services/auth_check.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  @override
  Widget build(BuildContext context) {
    // O StoreConnector agora vive aqui, fora do MaterialApp,
    // ouvindo o estado de login e o tema.
    return StoreConnector<AppState, _ViewModel>(
      converter: (store) => _ViewModel.fromStore(store),
      builder: (context, vm) {
        // Envolve tudo em um MaterialApp "básico" para telas de login/loading.
        // O MaterialApp "completo" com o tema do Redux será construído quando o usuário estiver logado.
        if (!vm.isLoggedIn && !vm.isGuest) {
          return MaterialApp(
              debugShowCheckedModeBanner: false,
              // Um tema fixo para a tela de login
              theme: ThemeData.dark(),
              home: StreamBuilder<User?>(
                stream: FirebaseAuth.instance.authStateChanges(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Scaffold(
                        body: Center(child: CircularProgressIndicator()));
                  }
                  // Se o stream tem dados (usuário logado), ele será pego pelo StoreConnector na próxima reconstrução.
                  // Enquanto isso, mostramos um loader para evitar um flash da tela de login.
                  if (snapshot.hasData) {
                    return const Scaffold(
                        body: Center(child: CircularProgressIndicator()));
                  }
                  // Se não tem usuário Firebase, mostra a tela de Start.
                  return const StartScreenPage();
                },
              ),
              // Rotas para as telas de login/cadastro
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
              });
        }

        // Se o usuário está logado ou é convidado, constrói o MaterialApp completo.
        return MaterialApp(
          navigatorKey: navigatorKey,
          debugShowCheckedModeBanner: false,
          theme: vm.theme, // <<< Usa o tema do Redux
          home: const MainAppScreen(), // <<< A tela principal
          onGenerateRoute:
              NavigationService.generateRoute, // Suas rotas globais
        );
      },
      onInit: (store) {
        // Configura o listener do Firebase uma vez para despachar ações ao Redux.
        FirebaseAuth.instance.authStateChanges().listen((user) {
          if (user != null) {
            // Se o usuário logou, mas o Redux ainda não sabe, inicia o processamento.
            if (!store.state.userState.isLoggedIn) {
              _processUserLogin(store, user);
            }
          } else {
            // Se o usuário deslogou, mas o Redux ainda acha que está logado.
            if (store.state.userState.isLoggedIn) {
              store.dispatch(UserLoggedOutAction());
            }
          }
        });
      },
    );
  }

  Future<void> _processUserLogin(Store<AppState> store, User user) async {
    print("AuthCheck: Iniciando processamento para ${user.uid}");

    // 1. Despacha ação de login para o estado Redux saber que estamos autenticados.
    store.dispatch(UserLoggedInAction(
      userId: user.uid,
      email: user.email ?? '',
      nome: user.displayName ?? 'Usuário',
    ));

    // 2. Verifica/cria o documento do usuário no Firestore.
    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userDocRef.get();

    if (!docSnapshot.exists) {
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
      print("AuthCheck: Usuário existente. Carregando detalhes.");
      store.dispatch(UserDetailsLoadedAction(docSnapshot.data()!));
    }

    print(
        "AuthCheck: Despachando ações para carregar dados adicionais (progresso, notas, etc).");
    store.dispatch(LoadAllBibleProgressAction());
    store.dispatch(LoadUserNotesAction());
    store.dispatch(LoadUserHighlightsAction());
    store.dispatch(LoadAdLimitDataAction());
    store.dispatch(LoadUserDiariesAction());
    store.dispatch(LoadUserCollectionsAction());

    print("AuthCheck: Processamento concluído para ${user.uid}.");
  }
}

// ViewModel para o StoreConnector em AuthCheck
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
