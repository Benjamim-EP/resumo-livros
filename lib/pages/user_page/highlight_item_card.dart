// lib/pages/user_page/highlight_item_card.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/models/highlight_item_model.dart';
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

  // Função auxiliar para converter o hex da cor para um objeto Color.
  // Retorna uma cor padrão se o hex for inválido ou nulo.
  Color _parseColor(String? hexColor, Color defaultColor) {
    if (hexColor == null || hexColor.isEmpty) return defaultColor;
    try {
      return Color(int.parse(hexColor.replaceFirst('#', '0xff')));
    } catch (e) {
      return defaultColor;
    }
  }

  void _handleTap(BuildContext context) {
    final sourceType = item.originalData['sourceType'] as String?;

    if (item.type == HighlightItemType.literature) {
      if (sourceType == 'sermon') {
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
        showDialog(
          context: context,
          builder: (_) => CommentHighlightDetailDialog(
            referenceText: item.referenceText,
            fullCommentText:
                item.originalData['fullContext'] ?? 'Contexto não encontrado.',
            selectedSnippet: item.contentPreview,
            highlightColor: _parseColor(item.colorHex, Colors.amber),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isVerse = item.type == HighlightItemType.verse;

    // Define as cores com base na cor do destaque.
    final Color baseColor = _parseColor(
        item.colorHex, isVerse ? Colors.blue.shade700 : Colors.amber.shade700);

    // Usa a cor do card do tema como base para o degradê.
    final Color cardBackgroundColor = theme.cardColor;

    // Lógica para determinar o ícone com base no tipo de fonte.
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
      default:
        sourceIcon = Icons.menu_book_outlined;
    }

    return Card(
      elevation: 2,
      // A cor do card em si é transparente para que o Container interno mostre o degradê.
      color: Colors.transparent,
      shadowColor: baseColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias, // Garante que o InkWell respeite as bordas.
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isVerse ? null : () => _handleTap(context),
        splashColor: baseColor.withOpacity(0.1),
        highlightColor: baseColor.withOpacity(0.05),
        child: Container(
          // O Container agora é o responsável pelo visual de fundo.
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                baseColor.withOpacity(0.15), // Cor do destaque, mais sutil
                cardBackgroundColor, // Cor de fundo do card
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              stops: const [0.0, 0.8], // Controla a transição do degradê
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Linha superior com Ícone, Referência e Botão de Deletar
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      sourceIcon,
                      color: baseColor, // Ícone usa a cor do destaque
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.referenceText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color:
                              baseColor, // Título também usa a cor do destaque
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(Icons.delete_outline,
                          color: theme.colorScheme.onSurface.withOpacity(0.5),
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
                const SizedBox(height: 12),

                // Corpo do Card: exibe o texto completo do versículo ou o trecho da literatura
                Text(
                  isVerse
                      ? (item.originalData['fullVerseText'] ??
                          'Carregando texto...')
                      : '"${item.contentPreview}"',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    height: 1.5,
                    fontStyle: isVerse ? FontStyle.normal : FontStyle.italic,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.85),
                  ),
                  maxLines: isVerse ? 10 : 4,
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
                              label: Text(tag,
                                  style: const TextStyle(fontSize: 11)),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.shrinkWrap,
                              visualDensity: VisualDensity.compact,
                              backgroundColor: baseColor.withOpacity(0.1),
                              side:
                                  BorderSide(color: baseColor.withOpacity(0.3)),
                            ))
                        .toList(),
                  )
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
