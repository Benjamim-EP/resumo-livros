import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/services/user_service.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';

final UserService _userService = UserService();

Future<User?> signInWithEmail(String email, String password) async {
  try {
    print("Tentando fazer login com email: $email");
    UserCredential userCredential =
        await FirebaseAuth.instance.signInWithEmailAndPassword(
      email: email,
      password: password,
    );

    print("Usuário autenticado: ${userCredential.user?.uid}");

    // Buscar os dados do usuário no Firestore
    final userData = await _userService.getUserByEmail(email);

    if (userData != null) {
      // Atualizar o estado global do usuário
      store.dispatch(UserLoggedInAction(
        userId: userCredential.user!.uid,
        email: userCredential.user!.email!,
        nome: userData['nome'] ?? 'Usuário',
      ));
    } else {
      // Usuário não existe no Firestore, criar um novo documento
      print("Criando novo usuário no Firestore para email: $email");

      final newUser = {
        'email': email,
        'nome': 'Usuário' // Nome padrão, ou peça ao usuário para inserir
      };
      await FirebaseFirestore.instance
          .collection('users')
          .doc(userCredential.user!.uid)
          .set(newUser);

      // Atualizar o estado com o novo usuário criado
      store.dispatch(UserLoggedInAction(
        userId: userCredential.user!.uid,
        email: userCredential.user!.email!,
        nome: newUser['nome']!,
      ));
    }

    return userCredential.user;
  } on FirebaseAuthException catch (e) {
    print("Erro no login com email: ${e.code} - ${e.message}");
    return null;
  } catch (e) {
    print("Erro inesperado: $e");
    return null;
  }
}
