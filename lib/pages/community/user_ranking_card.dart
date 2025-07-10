// lib/pages/community/user_ranking_card.dart
import 'package:flutter/material.dart';

class UserRankingCard extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final String score;
  final int rank;

  const UserRankingCard({
    super.key,
    required this.name,
    this.photoUrl,
    required this.score,
    required this.rank,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Gradiente roxo inspirado na imagem
    final gradient = LinearGradient(
      colors: [
        Colors.deepPurple.shade300,
        Colors.purple.shade400,
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Card(
      elevation: 8,
      shadowColor: Colors.purple.withOpacity(0.4),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias, // Garante que o gradiente não vaze
      child: Container(
        decoration: BoxDecoration(
          gradient: gradient,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            CircleAvatar(
              radius: 24,
              backgroundColor: Colors.white24,
              backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                  ? NetworkImage(photoUrl!)
                  : null,
              child: photoUrl == null || photoUrl!.isEmpty
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : 'U',
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 16),

            // Nome e Score
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Score: $score',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Indicador de Posição (Seta e Número)
            Row(
              children: [
                const Icon(Icons.arrow_upward,
                    color: Colors.greenAccent, size: 16),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: Colors.white.withOpacity(0.5), width: 1.5),
                  ),
                  child: Text(
                    '$rank',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}
