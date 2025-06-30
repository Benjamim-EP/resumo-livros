// lib/pages/user_page/highlight_item_card.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/models/highlight_item_model.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/pages/sermon_detail_page.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/pages/user_page/comment_highlight_detail_dialog.dart';

class HighlightItemCard extends StatelessWidget {
  final HighlightItem item;
  final Function(String) onNavigateToVerse;

  const HighlightItemCard({
    super.key,
    required this.item,
    required this.onNavigateToVerse,
  });

  void _handleTap(BuildContext context) {
    final sourceType = item.originalData['sourceType'] as String?;

    // Ação só acontece para LITERATURA
    if (item.type == HighlightItemType.literature) {
      if (sourceType == 'sermon') {
        // Navega para a página do Sermão
        final sermonId = item.originalData['sourceId'] as String?;
        final sermonTitle = item.originalData['sourceTitle'] as String?;
        if (sermonId != null && sermonTitle != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => SermonDetailPage(
                sermonGeneratedId: sermonId,
                sermonTitle: sermonTitle,
                snippetToScrollTo: item.contentPreview,
              ),
            ),
          );
        }
      } else {
        // Abre o diálogo para outros tipos de literatura
        showDialog(
          context: context,
          builder: (_) => CommentHighlightDetailDialog(
            referenceText: item.referenceText,
            fullCommentText:
                item.originalData['fullContext'] ?? 'Contexto não encontrado.',
            selectedSnippet: item.contentPreview,
            highlightColor: item.colorHex != null
                ? Color(int.parse(item.colorHex!.replaceFirst('#', '0xff')))
                : Colors.amber,
          ),
        );
      }
    }
    // Se for um versículo, não faz nada
  }

  // Em: lib/pages/user_page/highlight_item_card.dart -> dentro da classe HighlightItemCard

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isVerse = item.type == HighlightItemType.verse;

    // Define a cor do indicador baseada no tipo e nos dados salvos
    final Color indicatorColor = item.colorHex != null
        ? Color(int.parse(item.colorHex!.replaceFirst('#', '0xff')))
        : (isVerse
            ? Colors.blue.shade700
            : Colors.amber.shade700); // Cores padrão diferentes

    // Lógica para determinar o ícone com base no tipo de fonte
    final sourceType = item.originalData['sourceType'] as String?;
    IconData sourceIcon;
    switch (sourceType) {
      case 'sermon':
        sourceIcon = Icons.campaign_outlined;
        break;
      case 'church_history':
        sourceIcon = Icons.history_edu_outlined;
        break;
      case 'turretin':
        sourceIcon = Icons.school_outlined;
        break;
      case 'bible_commentary':
        sourceIcon = Icons.comment_outlined;
        break;
      default: // Inclui HighlightItemType.verse
        sourceIcon = Icons.menu_book_outlined;
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: indicatorColor.withOpacity(0.5), width: 1),
      ),
      // O InkWell fornece o efeito de toque, mas a ação onTap é condicional
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        // Se for um versículo, o onTap é nulo (desativado). Caso contrário, chama _handleTap.
        onTap: isVerse ? null : () => _handleTap(context),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha superior com Ícone, Referência e Botão de Deletar
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    sourceIcon, // Usa o ícone determinado pela lógica acima
                    color: indicatorColor,
                    size: 22,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item.referenceText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: indicatorColor,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline,
                        color: theme.colorScheme.error.withOpacity(0.7),
                        size: 22),
                    tooltip: "Remover Destaque",
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    visualDensity: VisualDensity.compact,
                    onPressed: () {
                      final store =
                          StoreProvider.of<AppState>(context, listen: false);
                      if (isVerse) {
                        store.dispatch(ToggleHighlightAction(item.id));
                      } else {
                        store.dispatch(RemoveCommentHighlightAction(item.id));
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Divider(height: 1, color: theme.dividerColor.withOpacity(0.2)),
              const SizedBox(height: 10),

              // Corpo do Card: exibe o texto completo do versículo ou o trecho da literatura
              Text(
                isVerse
                    ? (item.originalData['fullVerseText'] ??
                        'Carregando texto...')
                    : '"${item.contentPreview}"',
                style: theme.textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  fontStyle: isVerse ? FontStyle.normal : FontStyle.italic,
                ),
                maxLines: isVerse ? 10 : 4, // Mais linhas para versículos
                overflow: TextOverflow.ellipsis,
              ),

              // Seção de Tags (se existirem)
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6.0,
                  runSpacing: 4.0,
                  children: item.tags
                      .map((tag) => Chip(
                            label:
                                Text(tag, style: const TextStyle(fontSize: 10)),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 0),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            backgroundColor: theme
                                .colorScheme.secondaryContainer
                                .withOpacity(0.5),
                          ))
                      .toList(),
                )
              ],
            ],
          ),
        ),
      ),
    );
  }
}
