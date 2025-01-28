import 'package:firebase_auth/firebase_auth.dart';

Future<void> signInAnonymously() async {
  try {
    UserCredential userCredential =
        await FirebaseAuth.instance.signInAnonymously();
    print('Usuário anônimo logado: ${userCredential.user?.uid}');
  } on FirebaseAuthException catch (e) {
    print('Erro ao fazer login anônimo: $e');
  }
}
