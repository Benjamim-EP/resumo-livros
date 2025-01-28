import 'package:flutter/material.dart';

class Avatar extends StatelessWidget {
  final String? triboImage;

  const Avatar({super.key, this.triboImage});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Imagem principal do usuário
        ClipRRect(
          borderRadius: BorderRadius.circular(78), // Forma arredondada
          child: Image.network(
            "https://via.placeholder.com/150x150",
            width: 150,
            height: 150,
            fit: BoxFit.cover,
          ),
        ),
        // Borda ao redor da imagem
        Container(
          width: 155,
          height: 155,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFFCDE7BE), width: 1),
          ),
        ),
        // Imagem da tribo no canto inferior direito
        if (triboImage != null)
          Positioned(
            bottom: 0,
            right: 0,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8), // Forma mais quadrada
              child: Image.asset(
                triboImage!,
                width: 51, // Tamanho ajustado
                height: 36,
                fit: BoxFit.cover,
              ),
            ),
          ),
      ],
    );
  }
}
