// lib/pages/community/ranking_list_item.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/community/public_profile_page.dart';
import 'package:septima_biblia/pages/community/ranking_tab_view.dart'; // Para o modelo RankingUser
import 'package:septima_biblia/services/custom_page_route.dart';

class RankingListItem extends StatelessWidget {
  final int rank;
  // Recebe o objeto completo do usuário para ter acesso a todos os seus dados (ID, nome, foto, etc.)
  final RankingUser user;

  const RankingListItem({
    super.key,
    required this.rank,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // --- LÓGICA PARA DEFINIR O ÍCONE DE TENDÊNCIA ---
    Widget trendWidget;
    if (user.previousRank != null) {
      if (rank < user.previousRank!) {
        // Subiu no ranking
        trendWidget = const Icon(Icons.arrow_drop_up,
            color: Colors.greenAccent, size: 24);
      } else if (rank > user.previousRank!) {
        // Desceu no ranking
        trendWidget = const Icon(Icons.arrow_drop_down,
            color: Colors.redAccent, size: 24);
      } else {
        // Manteve a posição
        trendWidget = Icon(Icons.remove, color: Colors.grey.shade600, size: 20);
      }
    } else {
      // Sem dados da semana anterior
      trendWidget =
          const SizedBox(width: 24); // Espaço vazio para manter o alinhamento
    }
    // --- FIM DA LÓGICA DO ÍCONE ---

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 5.0),
      color: theme.cardColor.withOpacity(0.85),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip
          .antiAlias, // Garante que o InkWell respeite as bordas arredondadas
      child: Stack(
        // Usamos Stack para sobrepor o InkWell e capturar o toque em toda a área do card
        children: [
          // 1. Conteúdo visual do Card
          Padding(
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
                  backgroundImage:
                      user.photoURL != null && user.photoURL!.isNotEmpty
                          ? NetworkImage(user.photoURL!)
                          : null,
                  child: user.photoURL == null || user.photoURL!.isEmpty
                      ? Text(
                          user.name.isNotEmpty
                              ? user.name[0].toUpperCase()
                              : '?',
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
                        'Score Semanal: ${user.rankingScore.toStringAsFixed(0)}',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.7),
                        ),
                      ),

                      // ✅ ADICIONE ESTE TEXTO PARA O SCORE TOTAL
                      Text(
                        'Score Total: ${user.lifetimeScore.toStringAsFixed(0)}',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11, // Fonte menor
                          color: theme.textTheme.bodySmall?.color
                              ?.withOpacity(0.6),
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

          // 2. Camada de feedback de toque (InkWell) que cobre todo o card
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Ação de clique: navegar para o perfil público do usuário
                  Navigator.push(
                    context,
                    FadeScalePageRoute(
                      // Usando sua transição de página customizada
                      page: PublicProfilePage(
                        userId: user.id,
                        // Passa os dados que já temos para evitar um loading inicial na próxima tela
                        initialUserData: {
                          'userId': user.id,
                          'nome': user.name,
                          'photoURL': user.photoURL,
                        },
                      ),
                    ),
                  );
                },
                splashColor: theme.colorScheme.primary.withOpacity(0.12),
                highlightColor: theme.colorScheme.primary.withOpacity(0.08),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
