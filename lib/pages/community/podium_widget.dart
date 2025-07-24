// lib/pages/community/podium_widget.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/community/public_profile_page.dart';
import 'package:septima_biblia/pages/community/ranking_tab_view.dart'; // Importa o modelo RankingUser
import 'package:septima_biblia/services/custom_page_route.dart'; // Importa a transição de página customizada

/// Um widget que exibe os 3 melhores usuários do ranking em um pódio.
/// Cada membro do pódio é clicável e leva ao seu perfil público.
class PodiumWidget extends StatelessWidget {
  final List<RankingUser> users;

  const PodiumWidget({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    // Pega os usuários para cada posição, tratando o caso de haver menos de 3.
    final firstPlace = users.isNotEmpty ? users[0] : null;
    final secondPlace = users.length > 1 ? users[1] : null;
    final thirdPlace = users.length > 2 ? users[2] : null;

    return SizedBox(
      height: 280, // Altura fixa para o widget do pódio
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            // Segundo lugar (à esquerda)
            if (secondPlace != null)
              Expanded(
                child: _buildPodiumMember(context, secondPlace, 2, 160),
              ),
            // Primeiro lugar (no centro e mais alto)
            if (firstPlace != null)
              Expanded(
                child: _buildPodiumMember(context, firstPlace, 1, 200,
                    isWinner: true),
              ),
            // Terceiro lugar (à direita)
            if (thirdPlace != null)
              Expanded(
                child: _buildPodiumMember(context, thirdPlace, 3, 160),
              ),
          ],
        ),
      ),
    );
  }

  /// Constrói a representação visual para um único membro do pódio.
  /// O widget inteiro é envolvido por um [GestureDetector] para torná-lo clicável.
  Widget _buildPodiumMember(
    BuildContext context,
    RankingUser user,
    int rank,
    double height, {
    bool isWinner = false,
  }) {
    final theme = Theme.of(context);

    // Define a cor da borda com base na posição no pódio
    Color borderColor;
    if (isWinner) {
      borderColor = Colors.amber.shade600; // Ouro
    } else if (rank == 2) {
      borderColor = Colors.grey.shade400; // Prata
    } else {
      borderColor = Colors.brown.shade400; // Bronze
    }

    final double avatarRadius = isWinner ? 45 : 38;

    // GestureDetector captura o toque do usuário e aciona a navegação.
    return GestureDetector(
      onTap: () {
        // Navega para a página de perfil público do usuário selecionado.
        Navigator.push(
          context,
          FadeScalePageRoute(
            page: PublicProfilePage(
              userId: user.id,
              // Passamos os dados que já temos para que a próxima tela
              // possa exibir informações básicas imediatamente, antes de buscar mais detalhes.
              initialUserData: {
                'userId': user.id,
                'nome': user.name,
                'photoURL': user.photoURL,
              },
            ),
          ),
        );
      },
      child: SizedBox(
        height: height,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // Coroa para o primeiro lugar
            if (isWinner)
              const Text(
                '👑',
                style: TextStyle(
                  fontSize: 28,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
                ),
              ),
            if (isWinner) const SizedBox(height: 4),

            // Avatar com a borda colorida e a posição
            Stack(
              alignment: Alignment.bottomCenter,
              clipBehavior:
                  Clip.none, // Permite que o número da posição "vaze" para fora
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: borderColor, width: 3),
                    boxShadow: [
                      BoxShadow(
                        color: borderColor.withOpacity(0.5),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: CircleAvatar(
                    radius: avatarRadius,
                    backgroundColor: theme.cardColor,
                    backgroundImage:
                        user.photoURL != null && user.photoURL!.isNotEmpty
                            ? NetworkImage(user.photoURL!)
                            : null,
                    child: user.photoURL == null || user.photoURL!.isEmpty
                        ? Text(
                            user.name.isNotEmpty
                                ? user.name[0].toUpperCase()
                                : "?",
                            style: TextStyle(
                              fontSize: avatarRadius * 0.7,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                ),

                // Chip com o número da posição
                Positioned(
                  bottom: -8,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: theme.scaffoldBackgroundColor,
                        width: 2,
                      ),
                    ),
                    child: Text(
                      rank.toString(),
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Nome do usuário
            Flexible(
              child: Text(
                user.name,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 4),

            // Pontuação (Score)
            Text(
              user.rankingScore.toStringAsFixed(0),
              style: TextStyle(
                color: theme.colorScheme.primary,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
