import 'package:flutter/material.dart';
import 'topicHeader/topic_header.dart';
import 'bookFrame/book_frame.dart';

class BooksSection extends StatelessWidget {
  final String label;
  final List<Map<String, String>>
      books; // Lista de livros com 'cover' e 'title'

  const BooksSection({
    super.key,
    required this.label,
    required this.books,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: MediaQuery.of(context).size.width, // Largura da tela
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TopicHeader(label: label),
          const SizedBox(height: 16),
          SizedBox(
            height: 200, // Altura fixa para o carrossel
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: books.length,
              itemBuilder: (context, index) {
                final book = books[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: GestureDetector(
                    onTap: () {
                      Navigator.of(context).pushNamed(
                        '/bookDetails',
                        arguments: book['bookId'],
                      );
                    },
                    child: BookFrame(
                      cover: book['cover']!, // Link para a capa
                      title: book['title']!, // Título do livro
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
