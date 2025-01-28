import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:flutter_redux/flutter_redux.dart';

class AuthCheck extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasData) {
          final user = snapshot.data!;
          WidgetsBinding.instance.addPostFrameCallback((_) async {
            final store = StoreProvider.of<AppState>(context, listen: false);

            // Atualiza o estado do Redux com os dados do usuário
            store.dispatch(UserLoggedInAction(
              userId: user.uid,
              email: user.email ?? '',
              nome: user.displayName ?? '',
            ));

            // Verifica o campo "firstLogin" no Firestore
            final userDoc =
                FirebaseFirestore.instance.collection('users').doc(user.uid);
            final docSnapshot = await userDoc.get();

            if (docSnapshot.exists) {
              final isFirstLogin = docSnapshot.data()?['firstLogin'] ?? false;

              if (isFirstLogin) {
                // Redireciona para a tela de seleção de tribo
                Navigator.pushReplacementNamed(context, '/finalForm');
              } else {
                // Redireciona para a tela principal
                Navigator.pushReplacementNamed(context, '/mainAppScreen');
              }
            } else {
              // Se o documento do usuário não existe, cria com "firstLogin = true"
              await userDoc.set({'firstLogin': true});
              Navigator.pushReplacementNamed(context, '/finalForm');
            }
          });

          return const SizedBox(); // Página intermediária vazia enquanto redireciona
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacementNamed(
                context, '/startScreen'); // se não estiver logado
            //Navigator.pushReplacementNamed(context, '/login');
          });
          return const SizedBox();
        }
      },
    );
  }
}
