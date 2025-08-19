// lib/pages/biblie_page/recommended_resource_card.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/biblie_page/library_resource_viewer_modal.dart';
import 'package:septima_biblia/services/library_content_service.dart';

class RecommendedResourceCard extends StatelessWidget {
  final String contentId;
  final String reason;

  const RecommendedResourceCard({
    super.key,
    required this.contentId,
    required this.reason,
  });

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

  Future<void> _handleTap(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );
    try {
      final contentUnitPreview =
          await LibraryContentService.instance.getContentUnitPreview(contentId);
      if (contentUnitPreview == null) {
        throw Exception("Dados do recurso não encontrados no banco de dados.");
      }
      final fullContent =
          await LibraryContentService.instance.getFullContent(contentId);
      if (context.mounted) Navigator.pop(context);
      if (fullContent != null && context.mounted) {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => LibraryResourceViewerModal(
            title: contentUnitPreview.title,
            path: contentUnitPreview.path,
            content: fullContent,
          ),
        );
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content:
                  Text('Não foi possível carregar o conteúdo deste recurso.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro ao carregar recurso: $e')),
        );
      }
    }
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
          onTap: () => _handleTap(context),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // <<< INÍCIO DA CORREÇÃO DEFINITIVA DE OVERFLOW >>>

                // 1. Título da Fonte (ocupa apenas o espaço que precisa)
                Text(
                  sourceTitle,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // 2. Título da Unidade (envolvido em Expanded)
                // Este widget agora é flexível e preencherá o espaço vertical
                // disponível entre o título da fonte e a seção da razão.
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 3, // Continua truncando se o texto for enorme
                    overflow: TextOverflow.ellipsis,
                  ),
                ),

                // O Spacer foi removido.

                // 3. Seção da Razão (ocupa apenas o espaço que precisa no final)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 8, thickness: 0.5),
                    Text(
                      reason,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(fontStyle: FontStyle.italic),
                      maxLines: 2, // Garante que a razão também não exploda
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                // <<< FIM DA CORREÇÃO DE OVERFLOW >>>
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
