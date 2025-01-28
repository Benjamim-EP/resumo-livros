// services/tag_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class TagService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<String>> fetchRandomTags(int count) async {
    try {
      // Busca apenas as tags que possuem o campo "livros"
      final snapshot = await _firestore
          .collection('tags')
          .where('livros',
              isNotEqualTo:
                  null) // Filtra os documentos que têm o campo "livros"
          .get();

      // Extrai os nomes das tags
      final tags = snapshot.docs
          .where((doc) =>
              doc.data().containsKey('livros')) // Garante que o campo existe
          .map((doc) => doc['tag_name'] as String)
          .toList();

      // Embaralha e seleciona as primeiras `count` tags
      tags.shuffle();
      return tags.take(count).toList();
    } catch (e) {
      print('Erro ao buscar tags com livros: $e');
      return [];
    }
  }
}
