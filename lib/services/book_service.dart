// lib/services/book_service.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class BookService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Busca os detalhes de um livro teológico específico pelo seu ID de documento.
  /// Retorna um mapa com os dados do livro ou null se não for encontrado.
  Future<Map<String, dynamic>?> fetchBookDetails(String bookId) async {
    try {
      // ✅ CORREÇÃO PRINCIPAL: Usa o nome da coleção "livros" em vez de "books".
      final bookSnapshot =
          await _firestore.collection('livros').doc(bookId).get();

      if (bookSnapshot.exists) {
        final data = bookSnapshot.data()!;

        // Mapeia os dados do Firestore para um formato consistente que a UI espera.
        // Isso é uma boa prática, pois desacopla sua UI da estrutura exata do banco de dados.
        return {
          'bookId': bookId, // Inclui o próprio ID para referência futura
          'titulo': data['titulo'] ?? 'Título Desconhecido',
          'authorId': data['autor'] ??
              'Autor Desconhecido', // O campo 'autor' contém o nome/ID do autor
          'cover':
              data['cover_principal'] ?? '', // Usa o campo 'cover_principal'
          'resumo': data['resumo'] ?? '',
          'temas': data['temas'] ?? '',
          'aplicacoes': data['aplicacoes'] ?? '',
          'perfil_leitor': data['perfil_leitor'] ?? '',
          'versoes': data['versoes'] as List<dynamic>? ??
              [], // Lista de versões para compra

          // Campos do sistema de tópicos antigo que podem não existir mais para estes livros.
          // Manter como nulos ou listas/mapas vazios para evitar erros na UI que ainda possa referenciá-los.
          'chapters': [],
          'totalTopicos': 0,
        };
      } else {
        // Se o documento não for encontrado, loga e retorna nulo.
        print('Livro com ID $bookId não encontrado na coleção "livros".');
        return null;
      }
    } catch (e) {
      // Em caso de erro de rede ou outro problema, loga e relança a exceção.
      print("Erro ao buscar detalhes do livro $bookId: $e");
      rethrow;
    }
  }

  // Se você tiver outras funções que interagem com livros, elas também devem usar a coleção 'livros'.
  // Exemplo de como seria a `fetchBooksByTag` se você a usasse:
  Future<List<Map<String, String>>> fetchBooksByTag(String tag) async {
    try {
      final tagSnapshot = await _firestore
          .collection('tags')
          .where('tag_name', isEqualTo: tag)
          .limit(1)
          .get();
      if (tagSnapshot.docs.isEmpty) return [];

      final bookIds =
          List<String>.from(tagSnapshot.docs.first.data()['livros'] ?? []);
      final List<Map<String, String>> books = [];

      for (final bookId in bookIds) {
        // ✅ Usa 'livros' aqui também
        final bookSnapshot =
            await _firestore.collection('livros').doc(bookId).get();
        if (bookSnapshot.exists) {
          books.add({
            'cover': bookSnapshot.data()?['cover_principal'] as String? ?? '',
            'title': bookSnapshot.data()?['titulo'] as String? ?? '',
            'bookId': bookId,
          });
        }
      }
      return books;
    } catch (e) {
      print("Erro ao buscar livros pela tag $tag: $e");
      return [];
    }
  }
}
