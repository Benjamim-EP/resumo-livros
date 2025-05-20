// lib/services/sign_in_google.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart'; // Importar GoogleSignIn
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
// Removido: import 'package:resumo_dos_deuses_flutter/redux/actions.dart'; // Se UpdateUserUidAction não for mais usada aqui
// Removido: import 'package:resumo_dos_deuses_flutter/redux/store.dart';   // Se store.dispatch não for mais usado aqui

Future<User?> signInWithGoogle(BuildContext context) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  final GoogleSignIn googleSignIn = GoogleSignIn(); // Instanciar

  try {
    // **PASSO CRUCIAL: Tentar deslogar do GoogleSignIn primeiro**
    // Isso ajuda a garantir que o seletor de contas seja mostrado se houver múltiplas contas
    // ou se o usuário quiser trocar de conta.
    try {
      await googleSignIn.signOut();
      print('GoogleSignIn signOut bem-sucedido (ou já estava deslogado).');
    } catch (e) {
      print(
          'Erro ao tentar googleSignIn.signOut(): $e. Prosseguindo com o signIn.');
      // Não é um erro crítico se o signOut falhar, podemos prosseguir para o signIn.
    }
    // Você também pode tentar googleSignIn.disconnect() se quiser uma desconexão mais completa,
    // mas signOut() geralmente é suficiente para forçar o seletor.
    // await googleSignIn.disconnect();

    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();

    if (googleUser == null) {
      print(
          'Login com Google cancelado pelo usuário ou falhou ao obter conta Google.');
      return null;
    }

    final GoogleSignInAuthentication googleAuth =
        await googleUser.authentication;
    print(
        'Credenciais do Google obtidas: AccessToken ${googleAuth.accessToken != null}, IDToken ${googleAuth.idToken != null}');

    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    final UserCredential userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final User? user = userCredential.user;

    if (user != null) {
      print('Usuário logado no Firebase com Google: ${user.email}');

      // A lógica de Redux e Firestore para criar/verificar usuário permanece a mesma
      final userDocRef =
          FirebaseFirestore.instance.collection('users').doc(user.uid);
      final docSnapshot = await userDocRef.get();

      if (!docSnapshot.exists) {
        print(
            'signInWithGoogle: Novo usuário. Criando documento no Firestore.');
        final Map<String, dynamic> newUserFirestoreData = {
          'userId': user.uid,
          'nome': user.displayName ?? 'Usuário Google',
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
        // A navegação é tratada pelo AuthCheck
      } else {
        print('signInWithGoogle: Usuário existente.');
        // A navegação é tratada pelo AuthCheck
      }
      return user;
    }
  } on FirebaseAuthException catch (e) {
    print(
        'Erro FirebaseAuthException no login com Google: ${e.code} - ${e.message}');
    if (context.mounted) {
      // Adicionar verificação de mounted
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Erro ao fazer login com Google: ${e.message ?? "Tente novamente"}')),
      );
    }
  } catch (e, s) {
    print('Erro geral no login com Google: $e');
    print(s);
    if (context.mounted) {
      // Adicionar verificação de mounted
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content:
                Text('Ocorreu um erro inesperado durante o login com Google.')),
      );
    }
  }
  return null;
}
