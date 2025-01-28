import 'package:cloud_firestore/cloud_firestore.dart';

class BookService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Busca livros por tag
  Future<List<Map<String, String>>> fetchBooksByTag(String tag) async {
    try {
      final tagSnapshot = await _firestore
          .collection('tags')
          .where('tag_name', isEqualTo: tag)
          .get();

      final List<Map<String, String>> books = [];
      for (final tagDoc in tagSnapshot.docs) {
        final bookIds = List<String>.from(tagDoc['livros'] ?? []);
        for (final bookId in bookIds) {
          final bookSnapshot =
              await _firestore.collection('books').doc(bookId).get();
          if (bookSnapshot.exists) {
            books.add({
              'cover': bookSnapshot['cover'] as String,
              'title': bookSnapshot['titulo'] as String,
              'bookId': bookId,
            });
          }
        }
      }
      return books;
    } catch (e) {
      print("Erro ao buscar livros para a tag $tag: $e");
      return [];
    }
  }

  // Busca detalhes de um livro por ID
  Future<Map<String, dynamic>?> fetchBookDetails(String bookId) async {
    try {
      final bookSnapshot =
          await _firestore.collection('books').doc(bookId).get();
      if (bookSnapshot.exists) {
        final data = bookSnapshot.data()!;
        final List<dynamic> chapters = data['capitulos'] ?? [];

        // Ordenar capítulos pelo título
        chapters.sort((a, b) {
          return (a['titulo'] as String).compareTo(b['titulo'] as String);
        });

        return {
          'authorId': data['autorId'] ?? '',
          'titulo': data['titulo'] ?? '',
          'cover': data['cover'] ?? '',
          'chapters': chapters,
          'nTopicos': data['n_topicos'] ?? 1,
          'bookId': bookId,
          'totalTopicos': data['totalTopicos'] ?? 1,
        };
      } else {
        print('Livro com ID $bookId não encontrado.');
      }
    } catch (e) {
      print("Erro ao buscar detalhes do livro $bookId: $e");
    }
    return null;
  }
}
