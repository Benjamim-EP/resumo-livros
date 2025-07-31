// lib/pages/community/course_card.dart

import 'package:flutter/material.dart';

class CourseCard extends StatelessWidget {
  final String title;
  final String coverUrl;
  final String intro; // <<< NOVO: Para a descrição
  final String qntReferencias; // <<< NOVO: Para as estatísticas
  final VoidCallback onTap;

  const CourseCard({
    super.key,
    required this.title,
    required this.coverUrl,
    required this.intro,
    required this.qntReferencias,
    required this.onTap,
  });

  // Widget auxiliar para as linhas de informação (reutilizado da Biblioteca)
  Widget _buildInfoRow(BuildContext context, IconData icon, String text) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon,
            size: 14,
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.6)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: theme.textTheme.bodySmall?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.9)),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Limpa a URL, pegando apenas a parte antes de qualquer "!"
    final cleanUrl = coverUrl.split('!').first;

    return Card(
      elevation: 4,
      margin: const EdgeInsets.all(0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- PARTE DA IMAGEM ---
            Expanded(
              flex: 3,
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  Positioned.fill(
                    child: cleanUrl.isNotEmpty
                        ? Image.network(
                            cleanUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                                color: theme.colorScheme.surfaceVariant),
                          )
                        : Container(color: theme.colorScheme.primaryContainer),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.85),
                          Colors.transparent
                        ],
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        stops: const [0.0, 0.8],
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 10,
                    left: 12,
                    right: 12,
                    child: Text(
                      title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 12, // Tamanho ajustado para caber melhor
                        shadows: [
                          const Shadow(blurRadius: 3.0, color: Colors.black87)
                        ],
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            // --- PARTE DAS INFORMAÇÕES ---
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Text(
                      intro, // Usa o campo 'intro'
                      style: theme.textTheme.bodySmall?.copyWith(height: 1.3),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Divider(height: 12, thickness: 0.5),
                    _buildInfoRow(
                      context,
                      Icons.library_books_outlined,
                      qntReferencias, // Usa o campo 'qntReferencias'
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
