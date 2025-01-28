import 'package:flutter/material.dart';

class BookDetails extends StatelessWidget {
  const BookDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título com overflow
        Text(
          'Cristianismo Puro e Simples',
          style: TextStyle(
            color: Color.fromARGB(255, 0, 0, 0),
            fontSize: 12,
            fontFamily: 'Abel',
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1, // Limita a uma linha
          overflow: TextOverflow.ellipsis, // Adiciona '...'
        ),
        // Autor com overflow
        Text(
          'C.S. Lewis',
          style: TextStyle(
            color: Color.fromARGB(255, 5, 5, 5),
            fontSize: 10,
            fontFamily: 'Abel',
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1, // Limita a uma linha
          overflow: TextOverflow.ellipsis, // Adiciona '...'
        ),
      ],
    );
  }
}
