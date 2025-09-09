// lib/pages/library_page/compact_resource_card.dart
import 'package:flutter/material.dart';

class CompactResourceCard extends StatelessWidget {
  final String title;
  final String author;
  final ImageProvider? coverImage;
  final VoidCallback onCardTap;
  final VoidCallback onExpandTap;
  final bool isPremium;

  const CompactResourceCard({
    super.key,
    required this.title,
    required this.author,
    this.coverImage,
    required this.onCardTap,
    required this.onExpandTap,
    this.isPremium = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // O widget Card não é mais necessário aqui, pois a borda e a elevação
    // podem ser controladas pelo Container principal para um visual mais limpo.
    return InkWell(
      onTap: onCardTap,
      borderRadius:
          BorderRadius.circular(8), // Efeito splash com bordas arredondadas
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. ÁREA DA CAPA DO LIVRO
          Expanded(
            child: Card(
              elevation: 4,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Imagem de Fundo
                  if (coverImage != null)
                    Image(image: coverImage!, fit: BoxFit.cover)
                  else
                    Container(color: theme.colorScheme.surfaceVariant),

                  // Botão de expandir sobreposto
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      icon: const Icon(Icons.more_vert,
                          color: Colors.white, size: 20),
                      tooltip: "Ver Detalhes",
                      onPressed: onExpandTap,
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.4),
                        shape: const CircleBorder(),
                        padding: const EdgeInsets.all(4),
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),

                  // Ícone Premium (se aplicável)
                  if (isPremium)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Icon(
                        Icons.workspace_premium_rounded,
                        color: Colors.amber.shade600,
                        size: 20,
                        shadows: const [
                          Shadow(blurRadius: 2, color: Colors.black)
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 8),

          // 2. ÁREA DE TEXTO (TÍTULO E AUTOR)
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            author,
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
