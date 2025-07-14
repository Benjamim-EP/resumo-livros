// lib/pages/library_page/recommendation_card.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/book_details_page.dart'; // Importa a página de detalhes

class RecommendationCard extends StatelessWidget {
  final Map<String, dynamic> recommendation;

  const RecommendationCard({
    super.key,
    required this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // Extrai os dados do mapa com segurança
    final String coverUrl = recommendation['cover'] as String? ?? '';
    final String title =
        recommendation['titulo'] as String? ?? 'Título Desconhecido';
    final String author =
        recommendation['autor'] as String? ?? 'Autor Desconhecido';
    final String reason = recommendation['recommendation_reason'] as String? ??
        'Recomendado para sua busca.';
    final String bookId = recommendation['book_id'] as String? ?? '';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seção da Justificativa (Destaque)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16.0),
            color: theme.colorScheme.primaryContainer.withOpacity(0.5),
            child: Text(
              '“$reason”',
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onPrimaryContainer,
              ),
            ),
          ),

          const Divider(height: 1, thickness: 1),

          // Seção de Informações do Livro
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagem da capa
                if (coverUrl.isNotEmpty)
                  SizedBox(
                    width: 80,
                    height: 120,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        coverUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) =>
                            Container(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                const SizedBox(width: 16),
                // Título, autor e botão
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        author,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: bookId.isNotEmpty
                              ? () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            BookDetailsPage(bookId: bookId)),
                                  );
                                }
                              : null,
                          child: const Text('Ver Livro'),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
