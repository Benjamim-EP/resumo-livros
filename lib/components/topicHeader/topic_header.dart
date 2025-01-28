import 'package:flutter/material.dart';

class TopicHeader extends StatelessWidget {
  final String label;

  const TopicHeader({
    required this.label,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity, // Garante que ocupe toda a largura disponível
      height: 60.0, // Altura fixa
      padding:
          const EdgeInsets.symmetric(horizontal: 16.0), // Espaçamento interno
      alignment: Alignment.centerLeft, // Alinha o texto à esquerda
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
