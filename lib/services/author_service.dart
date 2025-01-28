// author_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthorService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<Map<String, dynamic>?> fetchAuthorDetails(String authorId) async {
    try {
      final docSnapshot =
          await _firestore.collection('authors').doc(authorId).get();

      print(docSnapshot);
      if (docSnapshot.exists) {
        return docSnapshot.data();
      } else {
        print('Autor não encontrado: $authorId');
        return null;
      }
    } catch (e) {
      print('Erro ao buscar detalhes do autor: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllAuthors() async {
    try {
      final snapshot = await _firestore.collection('authors').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      print('Erro ao buscar autores: $e');
      return [];
    }
  }
}
