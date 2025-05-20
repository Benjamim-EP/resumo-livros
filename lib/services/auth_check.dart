// lib/services/auth_check.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resumo_dos_deuses_flutter/main.dart'; // Para navigatorKey
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:redux/redux.dart';

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key});

  Future<void> _processUser(
      BuildContext scaffoldContext, User user, Store<AppState> store) async {
    // Este método agora é chamado explicitamente e não depende tanto do addPostFrameCallback
    // para a lógica principal, apenas para a navegação se ainda não ocorreu.

    print("AuthCheck: _processUser - Iniciando para usuário ${user.uid}");

    // Despacha ação básica de login se ainda não estiver no estado Redux ou se for um usuário diferente
    if (store.state.userState.userId != user.uid ||
        !store.state.userState.isLoggedIn) {
      store.dispatch(UserLoggedInAction(
        userId: user.uid,
        email: user.email ?? '',
        nome: user.displayName ??
            '', // Nome inicial, será atualizado pelo Firestore
      ));
    }

    final userDocRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);
    final docSnapshot = await userDocRef.get();

    if (!scaffoldContext.mounted) return; // Verificar antes de usar o context

    if (docSnapshot.exists) {
      print(
          "AuthCheck: _processUser - Usuário ${user.uid} existente no Firestore.");
      final userDataFromFirestore = docSnapshot.data()!;
      Map<String, dynamic> migratedData = Map.from(userDataFromFirestore);
      // ... (lógica de migração de userCoins, etc.) ...
      bool needsMigrationUpdate = false;
      if (migratedData['userCoins'] == null) {
        migratedData['userCoins'] = 100;
        needsMigrationUpdate = true;
      }
      if (migratedData['rewardedAdsWatchedToday'] == null) {
        migratedData['rewardedAdsWatchedToday'] = 0;
        needsMigrationUpdate = true;
      }
      if (needsMigrationUpdate) {
        await userDocRef.update({
          'userCoins': migratedData['userCoins'],
          'rewardedAdsWatchedToday': migratedData['rewardedAdsWatchedToday'],
        });
      }
      store.dispatch(UserDetailsLoadedAction(migratedData));
    } else {
      print(
          "AuthCheck: _processUser - Novo usuário ${user.uid}. Criando documento.");
      final Map<String, dynamic> newUserFirestoreData = {
        'userId': user.uid,
        'nome': user.displayName ?? 'Novo Usuário',
        'email': user.email ?? '',
        'photoURL': user.photoURL ?? '',
        'dataCadastro': FieldValue.serverTimestamp(),
        'Dias': 0,
        'Livros': 0,
        'Tópicos': 0,
        'selos': 10,
        'descrição': "",
        'topicSaves': {},
        'booksProgress': {},
        'lastReadBookAbbrev': null,
        'lastReadChapter': null,
        'isPremium': {'status': 'inactive', 'expiration': null},
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
    }

    // A navegação para /mainAppScreen agora é feita pela LoginPage/SignUpPage.
    // O AuthCheck garante que, se o app for aberto e o usuário já estiver logado, ele vá para lá.
    // Se a rota atual NÃO for /mainAppScreen, então o AuthCheck força a navegação.
    // Isso é importante se o usuário abrir o app e já estiver logado.
    final currentRoute = ModalRoute.of(scaffoldContext)?.settings.name;
    if (currentRoute != '/mainAppScreen' && navigatorKey.currentState != null) {
      print(
          "AuthCheck: _processUser - Rota atual é '$currentRoute'. Navegando para /mainAppScreen via GlobalKey.");
      navigatorKey.currentState
          ?.pushNamedAndRemoveUntil('/mainAppScreen', (route) => false);
    } else if (navigatorKey.currentState == null) {
      print(
          "AuthCheck: _processUser - navigatorKey.currentState é null. Não pode navegar.");
    } else {
      print(
          "AuthCheck: _processUser - Já está na /mainAppScreen ou navegação já ocorreu.");
    }
  }

  @override
  Widget build(BuildContext context) {
    print("AuthCheck: Build method chamado.");
    return StoreBuilder<AppState>(
        // Usar StoreBuilder para ter acesso ao store no build
        builder: (context, store) {
      return StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          print(
              "AuthCheck StreamBuilder: State: ${snapshot.connectionState}, HasData: ${snapshot.hasData}, User: ${snapshot.data?.uid}");

          if (snapshot.connectionState == ConnectionState.waiting) {
            print("AuthCheck StreamBuilder: Waiting for connection...");
            return const Scaffold(
              key: ValueKey("AuthCheckInitialLoading"),
              body: Center(child: CircularProgressIndicator()),
            );
          }

          if (snapshot.connectionState == ConnectionState.active) {
            final User? user = snapshot.data;
            if (user != null) {
              print(
                  "AuthCheck StreamBuilder: User IS LOGGED IN (Firebase) - UID: ${user.uid}.");
              // Chama _processUser, que agora também lida com a navegação se necessário.
              // Usar Future.microtask para garantir que _processUser seja executado após o build atual.
              Future.microtask(() async {
                // Passar o context do StreamBuilder, que é válido neste momento.
                await _processUser(context, user, store);
              });
              // Retorna um loading enquanto o processamento e a possível navegação ocorrem.
              return const Scaffold(
                  body: Center(
                      child: CircularProgressIndicator(
                          key: ValueKey("AuthCheckProcessingUser"))));
            } else {
              print(
                  "AuthCheck StreamBuilder: No user data (logged out). Navigating to /startScreen after frame.");
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (navigatorKey.currentContext != null &&
                    navigatorKey.currentContext!.mounted) {
                  final currentRouteName =
                      ModalRoute.of(navigatorKey.currentContext!)
                          ?.settings
                          .name;
                  // Só navega se não estiver já indo para /startScreen ou /login para evitar loops
                  if (currentRouteName != '/startScreen' &&
                      currentRouteName != '/login') {
                    print(
                        "AuthCheck: Navigating to /startScreen via GlobalKey (user logged out).");
                    navigatorKey.currentState?.pushNamedAndRemoveUntil(
                        '/startScreen', (route) => false);
                  }
                }
              });
              return const Scaffold(
                  body: Center(
                      child: CircularProgressIndicator(
                          key: ValueKey("AuthCheckLoadingLoggedOutUser"))));
            }
          }
          print(
              "AuthCheck StreamBuilder: Fallback - ConnectionState: ${snapshot.connectionState}");
          return const Scaffold(
            key: ValueKey("AuthCheckFallbackLoading"),
            body: Center(child: Text("Verificando autenticação...")),
          );
        },
      );
    });
  }
}
