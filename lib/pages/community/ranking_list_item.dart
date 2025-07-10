// lib/pages/community/ranking_list_item.dart
import 'package:flutter/material.dart';

class RankingListItem extends StatelessWidget {
  final int rank;
  final String name;
  final String? photoUrl;
  final String score;
  final int? previousRank; // A posição do usuário na semana anterior

  const RankingListItem({
    super.key,
    required this.rank,
    required this.name,
    this.photoUrl,
    required this.score,
    this.previousRank,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // --- LÓGICA PARA DEFINIR O ÍCONE DE TENDÊNCIA ---
    Widget trendWidget;
    if (previousRank != null) {
      if (rank < previousRank!) {
        // Subiu no ranking
        trendWidget = const Icon(Icons.arrow_drop_up,
            color: Colors.greenAccent, size: 24);
      } else if (rank > previousRank!) {
        // Desceu no ranking
        trendWidget = const Icon(Icons.arrow_drop_down,
            color: Colors.redAccent, size: 24);
      } else {
        // Manteve a posição
        trendWidget = Icon(Icons.remove, color: Colors.grey.shade600, size: 20);
      }
    } else {
      // Usuário novo no ranking, sem posição anterior
      trendWidget = const SizedBox(width: 24); // Apenas um espaço vazio
    }
    // --- FIM DA LÓGICA DO ÍCONE ---

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      color: theme.cardColor.withOpacity(0.85), // Cor de fundo do card
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            // Posição no Ranking (à esquerda)
            SizedBox(
              width: 35,
              child: Text(
                '$rank',
                textAlign: TextAlign.center,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.8),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Avatar do Usuário
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.colorScheme.surface,
              backgroundImage: photoUrl != null && photoUrl!.isNotEmpty
                  ? NetworkImage(photoUrl!)
                  : null,
              child: photoUrl == null || photoUrl!.isEmpty
                  ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?',
                      style: const TextStyle(fontWeight: FontWeight.bold))
                  : null,
            ),
            const SizedBox(width: 16),

            // Coluna com Nome e Score
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Score: $score',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),

            // Ícone de tendência (à direita)
            trendWidget,
          ],
        ),
      ),
    );
  }
}
