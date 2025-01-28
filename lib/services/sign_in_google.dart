import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

Future<User?> signInWithGoogle(BuildContext context) async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp();
  }

  try {
    final googleUser = await GoogleSignIn().signIn();

    if (googleUser == null) {
      print('Login cancelado pelo usuário');
      return null;
    }

    final googleAuth = await googleUser.authentication;

    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    // Login no Firebase com credenciais do Google
    final userCredential =
        await FirebaseAuth.instance.signInWithCredential(credential);
    final user = userCredential.user;

    if (user != null) {
      print('Usuário logado com Google: ${user.email}');

      // Despachar a ação para salvar o UID no Redux
      store.dispatch(UpdateUserUidAction(user.uid));

      // Verifique se o usuário já está cadastrado no Firestore
      final userDoc =
          FirebaseFirestore.instance.collection('users').doc(user.uid);

      final docSnapshot = await userDoc.get();

      if (!docSnapshot.exists) {
        // Novo usuário - Salve os dados no Firestore
        await userDoc.set({
          'nome': user.displayName ?? '',
          'email': user.email ?? '',
          'photoURL': user.photoURL ?? '',
          'dataCadastro': DateTime.now().toIso8601String(),
          'Dias': 0,
          'Livros': 0,
          'Tópicos': 0,
          'firstLogin': true
        });
        print('Novo usuário cadastrado: ${user.email}');
        // Redireciona para a tela de primeiro login
        Navigator.pushReplacementNamed(context, '/finalForm');
      } else {
        // Usuário existente - Verifica o estado de "firstLogin"
        final isFirstLogin = docSnapshot.data()?['firstLogin'] ?? false;

        if (isFirstLogin) {
          // Redireciona para a tela de primeiro login
          Navigator.pushReplacementNamed(context, '/finalForm');
        } else {
          // Redireciona para a tela principal
          Navigator.pushReplacementNamed(context, '/mainAppScreen');
        }
      }
    }
    return user;
  } on FirebaseAuthException catch (e) {
    print('Erro ao fazer login com Google: ${e.message}');
  } catch (e) {
    print('Erro geral no login com Google: $e');
  }
}
