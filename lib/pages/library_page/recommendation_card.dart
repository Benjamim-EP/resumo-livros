// lib/pages/library_page/recommendation_card.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/book_details_page.dart';

class RecommendationCard extends StatelessWidget {
  final Map<String, dynamic> recommendation;

  const RecommendationCard({
    super.key,
    required this.recommendation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final String coverUrl = recommendation['cover'] as String? ?? '';
    final String title =
        recommendation['titulo'] as String? ?? 'Título Desconhecido';
    final String author =
        recommendation['autor'] as String? ?? 'Autor Desconhecido';
    final String reason = recommendation['recommendation_reason'] as String? ??
        'Recomendado para sua busca.';
    final String bookId = recommendation['book_id'] as String? ?? '';

    const double imageHeight = 120.0;
    const double imageWidth = 80.0;
    //print('RecommendationCard: $bookId, $title, $author, $coverUrl');
    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Seção da Justificativa
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
          // ✅ NOVA ESTRUTURA PARA A SEÇÃO DE INFORMAÇÕES
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Imagem da capa (com tamanho fixo)
                if (coverUrl.isNotEmpty)
                  SizedBox(
                    width: imageWidth,
                    height: imageHeight,
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

                // Coluna com Título, Autor e Botão
                Expanded(
                  // A Column agora está dentro de uma SizedBox com altura explícita
                  child: SizedBox(
                    height:
                        imageHeight, // Força a coluna a ter a mesma altura da imagem
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment:
                          MainAxisAlignment.start, // Alinha no topo
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
                        // Expanded dentro da Column força o botão a ir para o final
                        const Expanded(child: SizedBox()),
                        Align(
                          alignment: Alignment
                              .bottomRight, // Alinha o botão no canto inferior direito
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
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
