// lib/pages/biblie_page/recommended_resource_card.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/biblie_page/library_resource_viewer_modal.dart';
import 'package:septima_biblia/services/library_content_service.dart';

class RecommendedResourceCard extends StatelessWidget {
  final String contentId;
  final String title;
  final String reason;
  // <<< NOVO PARÂMETRO OPCIONAL >>>
  final String? sourceTitle; // Para não precisar decodificar

  const RecommendedResourceCard({
    super.key,
    required this.contentId,
    required this.title,
    required this.reason,
    this.sourceTitle, // Opcional
  });

  // <<< FUNÇÃO HELPER REMOVIDA >>>
  // A função _decodeContentId foi removida pois não é mais necessária.

  // A função onTap agora é mais simples e está dentro do build.
  // Ela apenas precisa abrir o modal, que fará o trabalho pesado.
  void _handleTap(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => LibraryResourceViewerModal(
        contentId: contentId, // O modal só precisa do ID para buscar tudo.
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // <<< LÓGICA DE TÍTULO SIMPLIFICADA >>>
    // Tenta usar o sourceTitle se ele for fornecido, senão usa um padrão.
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
                  displaySourceTitle, // Usa a variável local
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: theme.colorScheme.primary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    title, // Usa o title recebido diretamente
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

// A extensão capitalizeFirstOfEach não é mais usada aqui, mas pode deixar
// no arquivo se outros widgets a utilizarem.
extension StringExtension on String {
  String get capitalizeFirstOfEach => this
      .split(" ")
      .map((str) =>
          str.isEmpty ? "" : '${str[0].toUpperCase()}${str.substring(1)}')
      .join(" ");
}
