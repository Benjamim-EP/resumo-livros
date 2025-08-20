// lib/pages/biblie_page/recommended_resource_card.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/biblie_page/library_resource_viewer_modal.dart';

class RecommendedResourceCard extends StatelessWidget {
  final String contentId;
  final String reason;

  const RecommendedResourceCard({
    super.key,
    required this.contentId,
    required this.reason,
  });

  // Função para decodificar o ID (local e síncrona)
  Map<String, String> _decodeContentId(String id) {
    String sourceTitle = "Biblioteca";
    if (id.startsWith("turretin-elenctic-theology")) {
      sourceTitle = "Institutas de Turretin";
    } else if (id.startsWith("church-history-philip-schaff")) {
      sourceTitle = "História da Igreja";
    } else if (id.startsWith("gods-word-to-women-bushnell")) {
      sourceTitle = "A Palavra de Deus às Mulheres";
    }

    String title =
        id.split('_').last.replaceAll('-', ' ').capitalizeFirstOfEach;

    return {
      'sourceTitle': sourceTitle,
      'title': title,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final decodedInfo = _decodeContentId(contentId);
    final String sourceTitle = decodedInfo['sourceTitle']!;
    final String title = decodedInfo['title']!;

    return SizedBox(
      width: 220,
      child: Card(
        margin: const EdgeInsets.only(right: 12.0, top: 4.0, bottom: 4.0),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // <<< O TAP AGORA É MUITO MAIS SIMPLES >>>
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => LibraryResourceViewerModal(
                contentId: contentId, // Apenas passa o ID
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sourceTitle,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 8, thickness: 0.5),
                    Text(
                      reason,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Helper (sem alterações)
extension StringExtension on String {
  String get capitalizeFirstOfEach => this
      .split(" ")
      .map((str) =>
          str.isEmpty ? "" : '${str[0].toUpperCase()}${str.substring(1)}')
      .join(" ");
}
