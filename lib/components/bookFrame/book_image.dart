import 'package:flutter/material.dart';

class BookImage extends StatelessWidget {
  const BookImage({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 128,
      height: 184,
      padding: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            offset: const Offset(2, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Image.network(
        'https://m.media-amazon.com/images/I/91WAGXw7Y4L._SY466_.jpg',
        width: 128,
        height: 184,
        fit: BoxFit.cover, // Preenche completamente o espaço disponível
      ),
    );
  }
}
