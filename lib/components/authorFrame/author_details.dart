import 'package:flutter/material.dart';

class AuthorDetails extends StatelessWidget {
  const AuthorDetails({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Título com overflow
        Text(
          'C. S. Lewis',
          style: TextStyle(
            color: Color.fromARGB(255, 0, 0, 0),
            fontSize: 18,
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
