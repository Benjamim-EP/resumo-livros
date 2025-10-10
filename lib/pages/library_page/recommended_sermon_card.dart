// lib/pages/library_page/recommended_sermon_card.dart

import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/sermon_detail_page.dart';
import 'package:septima_biblia/services/custom_page_route.dart';

class RecommendedSermonCard extends StatelessWidget {
  final Map<String, dynamic> sermonData;

  const RecommendedSermonCard({
    super.key,
    required this.sermonData,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String title = sermonData['title_translated'] ?? 'Sermão Sem Título';
    final String reference = sermonData['main_scripture_abbreviated'] ?? '';
    final String sermonId = sermonData['sermon_id_base'] ?? '';

    return SizedBox(
      width: 150, // Largura fixa para cada card na lista horizontal
      child: Card(
        elevation: 3,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: InkWell(
          onTap: () {
            if (sermonId.isNotEmpty) {
              Navigator.push(
                context,
                FadeScalePageRoute(
                  page: SermonDetailPage(
                    sermonGeneratedId: sermonId,
                    sermonTitle: title,
                  ),
                ),
              );
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Área da "capa"
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: theme.colorScheme.secondaryContainer.withOpacity(0.4),
                  child: Center(
                    child: Icon(
                      Icons.campaign_outlined,
                      size: 40,
                      color: theme.colorScheme.onSecondaryContainer
                          .withOpacity(0.7),
                    ),
                  ),
                ),
              ),
              // Área de texto
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.2,
                      ),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    if (reference.isNotEmpty)
                      Text(
                        reference,
                        style: theme.textTheme.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
