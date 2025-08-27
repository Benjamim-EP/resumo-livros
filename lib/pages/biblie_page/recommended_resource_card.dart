// lib/pages/biblie_page/recommended_resource_card.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/biblie_page/library_resource_viewer_modal.dart';
import 'package:septima_biblia/services/library_content_service.dart';

class RecommendedResourceCard extends StatelessWidget {
  final String contentId;
  final String title;
  final String reason;
  final String? sourceTitle;

  const RecommendedResourceCard({
    super.key,
    required this.contentId,
    required this.title,
    required this.reason,
    this.sourceTitle,
  });

  void _handleTap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LibraryResourceViewerModal(
        contentId: contentId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final String displaySourceTitle = sourceTitle ?? "Biblioteca";

    return SizedBox(
      width: 220,
      child: Card(
        margin: const EdgeInsets.only(right: 12.0, top: 4.0, bottom: 4.0),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _handleTap(context),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displaySourceTitle,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // <<< INÍCIO DA CORREÇÃO >>>
                // Usamos Flexible para que o título use o espaço que precisa,
                // mas não force os outros widgets para fora.
                Flexible(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 1.3), // Melhora o espaçamento entre linhas
                    // maxLines e overflow garantem que textos muito longos sejam cortados elegantemente.
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // <<< FIM DA CORREÇÃO >>>

                const Spacer(), // O Spacer empurra o conteúdo abaixo para o final do card.

                const Divider(height: 8, thickness: 0.5),
                Text(
                  reason,
                  style: theme.textTheme.bodySmall
                      ?.copyWith(fontStyle: FontStyle.italic, height: 1.3),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
