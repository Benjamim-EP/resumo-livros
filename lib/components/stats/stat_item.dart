// lib/components/stats/stat_item.dart
import 'package:flutter/material.dart';

class StatsContainer extends StatelessWidget {
  final String stat1Value;
  final String stat1Label;
  final String stat2Value;
  final String stat2Label;

  const StatsContainer({
    super.key, // Adicionado super.key
    required this.stat1Value,
    required this.stat1Label,
    required this.stat2Value,
    required this.stat2Label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12), // Aumentei um pouco o padding
      decoration: BoxDecoration(
        color: const Color(0xFFCDE7BE), // Fundo verde
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          // Adicionando uma leve sombra para destaque
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            icon: Icons.collections_bookmark, // Ícone para coleções
            label: stat1Label,
            value: stat1Value,
          ),
          _buildStatItem(
            icon: Icons.edit_note, // Ícone para diário
            label: stat2Label,
            value: stat2Value,
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
          size: 28, // Ícone um pouco maior
          color: const Color(0xFF181A1A), // Cor escura
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF181A1A), // Texto escuro
            fontSize: 22, // Fonte maior para o valor
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            color: Color.fromARGB(255, 70, 73, 73), // Texto escuro mais suave
            fontSize: 13, // Fonte menor para o rótulo
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
        ),
      ],
    );
  }
}
