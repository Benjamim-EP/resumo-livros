import 'package:flutter/material.dart';

class AuthorImage extends StatelessWidget {
  const AuthorImage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 184,
      padding: const EdgeInsets.symmetric(vertical: 2),
      // decoration: BoxDecoration(
      //   boxShadow: [
      //     BoxShadow(
      //       color: Colors.black.withOpacity(0.10),
      //       offset: const Offset(2, 2),
      //       blurRadius: 4,
      //     ),
      //   ],
      // ),
      // Use Image.asset para carregar a imagem do asset
      child: Image.asset(
        'assets/images/authors/cs_lewis.webp',
        width: 128,
        height: 184,
        fit: BoxFit.cover, // Preenche completamente o espaço disponível
      ),
    );
  }
}
