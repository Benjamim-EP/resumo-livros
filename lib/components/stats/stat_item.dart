import 'package:flutter/material.dart';

class StatsContainer extends StatelessWidget {
  final String livros;
  final String topicos;

  const StatsContainer({
    required this.livros,
    required this.topicos,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFCDE7BE), // Fundo verde
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.book,
            label: 'Livros',
            value: livros,
          ),
          _buildStatItem(
            icon: Icons.topic,
            label: 'Tópicos',
            value: topicos,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          size: 24, // Ícone menor
          color: const Color(0xFF181A1A), // Cor escura
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF181A1A), // Texto escuro
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color.fromARGB(255, 85, 88, 88), // Texto escuro
            fontSize: 14,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}
