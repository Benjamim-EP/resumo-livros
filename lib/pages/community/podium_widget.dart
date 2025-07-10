// lib/pages/community/podium_widget.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/community/ranking_tab_view.dart';

class PodiumWidget extends StatelessWidget {
  final List<RankingUser> users;

  const PodiumWidget({super.key, required this.users});

  @override
  Widget build(BuildContext context) {
    final firstPlace = users.isNotEmpty ? users[0] : null;
    final secondPlace = users.length > 1 ? users[1] : null;
    final thirdPlace = users.length > 2 ? users[2] : null;

    return SizedBox(
      height: 280, // Altura aumentada para evitar overflow
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (secondPlace != null)
              Expanded(
                child: _buildPodiumMember(context, secondPlace, 2, 160),
              ),
            if (firstPlace != null)
              Expanded(
                child: _buildPodiumMember(context, firstPlace, 1, 200,
                    isWinner: true),
              ),
            if (thirdPlace != null)
              Expanded(
                child: _buildPodiumMember(context, thirdPlace, 3, 160),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPodiumMember(
    BuildContext context,
    RankingUser user,
    int rank,
    double height, {
    bool isWinner = false,
  }) {
    final theme = Theme.of(context);

    Color borderColor;
    if (isWinner) {
      borderColor = Colors.amber.shade600;
    } else if (rank == 2) {
      borderColor = Colors.grey.shade400;
    } else {
      borderColor = Colors.brown.shade400;
    }

    final double avatarRadius = isWinner ? 45 : 38;

    return SizedBox(
      height: height,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (isWinner)
            const Text(
              '👑',
              style: TextStyle(
                fontSize: 28,
                shadows: [Shadow(blurRadius: 4, color: Colors.black38)],
              ),
            ),
          if (isWinner) const SizedBox(height: 4),

          // Avatar + posição
          Stack(
            alignment: Alignment.bottomCenter,
            clipBehavior: Clip.hardEdge, // Impede overflow visível
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

              // Número da posição
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

          // Score
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
    );
  }
}
