// lib/pages/library_page/ai_recommendation_card.dart
import 'package:flutter/material.dart';

class AiRecommendationCard extends StatelessWidget {
  final Map<String, dynamic> recommendation;
  final VoidCallback onTap;

  const AiRecommendationCard({
    super.key,
    required this.recommendation,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String title = recommendation['title'] ?? 'Sem Título';
    final String author = recommendation['author'] ?? 'Desconhecido';
    final String coverPath = recommendation['coverImagePath'] ?? '';
    final String justification = recommendation['justificativa'] ?? '...';

    return Card(
      elevation: 4,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Capa do Livro
              if (coverPath.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    coverPath,
                    width: 80,
                    height: 120,
                    fit: BoxFit.cover,
                  ),
                ),
              const SizedBox(width: 16),
              // Informações
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: theme.textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(author, style: theme.textTheme.bodyMedium),
                    const Divider(height: 24),
                    Text(
                      justification,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontStyle: FontStyle.italic,
                        color:
                            theme.textTheme.bodyMedium?.color?.withOpacity(0.8),
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
