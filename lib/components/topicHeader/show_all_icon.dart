import 'package:flutter/material.dart';

// Componente para o ícone "Chevron Right" dentro de um círculo verde
class ShowAllIcon extends StatelessWidget {
  const ShowAllIcon({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24, // Define a largura e altura do círculo
      height: 24,
      decoration: BoxDecoration(
        color: const Color(0xFFCDE7BE), // Cor de fundo verde
        shape: BoxShape.circle, // Define a forma do Container como um círculo
      ),
      child: Icon(
        Icons.chevron_right, // Ícone de Chevron Right
        size: 16, // Tamanho do ícone
        color: Colors.black, // Cor do ícone: preto
      ),
    );
  }
}
