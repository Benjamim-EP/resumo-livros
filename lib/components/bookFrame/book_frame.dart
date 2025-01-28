import 'package:flutter/material.dart';

class BookFrame extends StatelessWidget {
  final String cover; // Link para a capa do livro
  final String title; // Título do livro

  const BookFrame({
    required this.cover,
    required this.title,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8.0),
          child: Image.network(
            cover,
            width: 100, // Largura fixa
            height: 150, // Altura fixa
            fit: BoxFit.cover,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return const Center(child: CircularProgressIndicator());
            },
            errorBuilder: (context, error, stackTrace) {
              return const Icon(Icons.error, size: 100); // Ícone de erro
            },
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 100, // Largura fixa
          child: Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
