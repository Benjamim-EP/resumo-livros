// lib/services/auth_check.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';

class AuthCheck extends StatelessWidget {
  const AuthCheck({super.key}); // Adicionado super.key e const

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            // Adicionado Scaffold para melhor aparência durante o loading
            body: Center(child: CircularProgressIndicator()),
          );
        } else if (snapshot.hasData) {
          final user = snapshot.data!;
          // Usar addPostFrameCallback para interagir com o Navigator e Store após o build.
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            // Garante que o widget ainda está montado antes de interagir com o context
            if (!context.mounted) return;

            final store = StoreProvider.of<AppState>(context, listen: false);

            // 1. Despacha UserLoggedInAction para atualizar o estado básico de login no Redux
            store.dispatch(UserLoggedInAction(
              userId: user.uid,
              email: user.email ?? '',
              nome: user.displayName ??
                  '', // Nome pode ser atualizado depois com UserDetailsLoadedAction
            ));

            final userDocRef =
                FirebaseFirestore.instance.collection('users').doc(user.uid);
            final docSnapshot = await userDocRef.get();

            if (docSnapshot.exists) {
              // Usuário existente
              print("AuthCheck: Usuário ${user.uid} existente no Firestore.");
              final userDataFromFirestore = docSnapshot.data()!;

              // Garante que os campos de moedas existam para usuários antigos
              bool needsMigrationUpdate = false;
              Map<String, dynamic> migratedData =
                  Map.from(userDataFromFirestore);

              if (migratedData['userCoins'] == null) {
                migratedData['userCoins'] = 100;
                needsMigrationUpdate = true;
              }
              if (migratedData['lastRewardedAdWatchTime'] == null) {
                // Não precisa definir se for null, mas marca para update se for adicionar outros
                // migratedData['lastRewardedAdWatchTime'] = null; // já seria null
              }
              if (migratedData['rewardedAdsWatchedToday'] == null) {
                migratedData['rewardedAdsWatchedToday'] = 0;
                needsMigrationUpdate = true;
              }

              if (needsMigrationUpdate) {
                await userDocRef.update({
                  'userCoins': migratedData['userCoins'],
                  // 'lastRewardedAdWatchTime': migratedData['lastRewardedAdWatchTime'], // não atualiza se for null
                  'rewardedAdsWatchedToday':
                      migratedData['rewardedAdsWatchedToday'],
                });
                print(
                    'AuthCheck: Campos de moedas adicionados/atualizados para usuário existente.');
              }

              store.dispatch(
                  UserDetailsLoadedAction(migratedData)); // Usa migratedData

              final isFirstLogin =
                  migratedData['firstLogin'] ?? false; // Usa migratedData
              store.dispatch(FirstLoginSuccessAction(isFirstLogin));

              if (!context.mounted)
                return; // Verifica novamente antes de navegar
              if (isFirstLogin) {
                Navigator.pushReplacementNamed(context, '/finalForm');
              } else {
                Navigator.pushReplacementNamed(context, '/mainAppScreen');
              }
            } else {
              // Novo usuário: criar documento no Firestore com todos os campos padrão
              print(
                  "AuthCheck: Novo usuário ${user.uid}. Criando documento no Firestore.");
              final Map<String, dynamic> newUserFirestoreData = {
                'userId': user.uid,
                'nome': user.displayName ?? 'Novo Usuário', // Ou um nome padrão
                'email': user.email ?? '',
                'photoURL': user.photoURL ?? '',
                'dataCadastro': FieldValue.serverTimestamp(),
                'Dias': 0,
                'Livros': 0,
                'Tópicos': 0,
                'firstLogin': true,
                'selos': 10,
                'descrição': "",
                'Tribo': null,
                'userFeatures': {},
                'indicacoes': {},
                'topicSaves': {},
                'booksProgress': {},
                'lastReadBookAbbrev': null,
                'lastReadChapter': null,
                'isPremium': {
                  'status': 'inactive',
                  'expiration': null
                }, // Estrutura de premium
                // Campos de Moedas e Anúncios
                'userCoins': 100,
                'lastRewardedAdWatchTime': null,
                'rewardedAdsWatchedToday': 0,
                // Campos de Assinatura Stripe
                'stripeCustomerId': null,
                'subscriptionStatus': 'inactive',
                'subscriptionEndDate': null,
                'stripeSubscriptionId': null,
                'activePriceId': null,
              };
              await userDocRef.set(newUserFirestoreData);

              // Despacha os detalhes completos para o Redux e o status de primeiro login
              store.dispatch(UserDetailsLoadedAction(newUserFirestoreData));
              store.dispatch(FirstLoginSuccessAction(true));

              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/finalForm');
            }
          });

          // Retorna um placeholder enquanto a lógica assíncrona e navegação ocorrem.
          // Um Scaffold vazio é melhor que apenas SizedBox() para evitar flashes de tela preta.
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        } else {
          // Usuário não está logado
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!context.mounted) return;
            Navigator.pushReplacementNamed(context, '/startScreen');
          });
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
      },
    );
  }
}
