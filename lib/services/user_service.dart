import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class UserService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Função para criar um usuário no Firestore
  Future<void> createUserInFirestore(User? user) async {
    if (user == null) return;

    final userDoc = _firestore.collection('users').doc(user.uid);

    // Verificar se o documento já existe
    final docSnapshot = await userDoc.get();
    if (!docSnapshot.exists) {
      // Se o documento não existir, criar novo usuário
      await userDoc.set({
        'userId': user.uid,
        'nome': user.displayName ?? 'Usuário Anônimo',
        'email': user.email,
        'compositoresCurtidos': [],
        'livrosLidos': [],
        'livrosNaoFinalizados': [],
        'trechosCurtidos': [],
        'indicacoes_autores': [],
        'indicacoes_livros': [],
        'indicacoes_rotas': [],
        'rankPalavrasLidas': 0,
        'dataCadastro': DateTime.now().toIso8601String(),
        'highlightsFavoritos': [],
        'topicosFavoritos': [],
        'rotas': [],
      });
    }
  }

  // Função para buscar dados do usuário pelo email
  Future<Map<String, dynamic>?> getUserByEmail(String email) async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        return querySnapshot.docs.first.data();
      } else {
        print("Nenhum usuário encontrado com este email: $email");
        return null;
      }
    } catch (e) {
      print("Erro ao buscar usuário por email: $e");
      return null;
    }
  }
}
