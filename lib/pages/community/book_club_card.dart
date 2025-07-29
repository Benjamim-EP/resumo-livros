// lib/pages/community/book_club_card.dart
import 'package:flutter/material.dart';

class BookClubCard extends StatelessWidget {
  final String bookId;
  final String title;
  final String author;
  final String coverUrl;
  final int participantCount;
  final VoidCallback onTap;

  const BookClubCard({
    super.key,
    required this.bookId,
    required this.title,
    required this.author,
    required this.coverUrl,
    required this.participantCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      elevation: 4,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 150,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Imagem de fundo
              if (coverUrl.isNotEmpty)
                Image.network(
                  coverUrl,
                  fit: BoxFit.cover,
                  // Efeito de desfoque sutil na imagem de fundo
                  color: Colors.black.withOpacity(0.5),
                  colorBlendMode: BlendMode.darken,
                ),
              // Gradiente para garantir a legibilidade do texto
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.4, 1.0],
                  ),
                ),
              ),
              // Contagem de participantes
              Positioned(
                top: 8,
                right: 8,
                child: Chip(
                  avatar: Icon(Icons.group,
                      size: 16, color: theme.colorScheme.onSecondaryContainer),
                  label: Text(participantCount.toString()),
                  labelStyle: TextStyle(
                      color: theme.colorScheme.onSecondaryContainer,
                      fontSize: 12),
                  backgroundColor:
                      theme.colorScheme.secondaryContainer.withOpacity(0.8),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              // Textos sobrepostos
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        shadows: [
                          const Shadow(blurRadius: 2, color: Colors.black)
                        ],
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      author,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: Colors.white.withOpacity(0.9),
                        shadows: [
                          const Shadow(blurRadius: 1, color: Colors.black)
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
