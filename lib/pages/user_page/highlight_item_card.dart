// lib/pages/user_page/highlight_item_card.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/models/highlight_item_model.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/redux/actions.dart';

class HighlightItemCard extends StatelessWidget {
  final HighlightItem item;
  final Function(String) onNavigateToVerse;

  const HighlightItemCard({
    super.key,
    required this.item,
    required this.onNavigateToVerse,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isVerse = item.type == HighlightItemType.verse;

    // Define a cor. Para comentários, usamos uma cor âmbar fixa.
    final Color indicatorColor = item.colorHex != null
        ? Color(int.parse(item.colorHex!.replaceFirst('#', '0xff')))
        : Colors.amber.shade700;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: indicatorColor.withOpacity(0.5), width: 1),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isVerse ? () => onNavigateToVerse(item.id) : null,
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Linha do Título com Ícone e Referência
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    isVerse ? Icons.menu_book_outlined : Icons.comment_outlined,
                    color: indicatorColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      item.referenceText,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: indicatorColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Conteúdo (Preview do comentário ou texto do versículo carregado)
              isVerse
                  ? FutureBuilder<String>(
                      future:
                          BiblePageHelper.loadSingleVerseText(item.id, 'nvi'),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState ==
                            ConnectionState.waiting) {
                          return Text("Carregando...",
                              style: theme.textTheme.bodySmall);
                        }
                        return Text(
                          snapshot.data ?? item.contentPreview,
                          style:
                              theme.textTheme.bodyMedium?.copyWith(height: 1.5),
                          maxLines: 4,
                          overflow: TextOverflow.ellipsis,
                        );
                      },
                    )
                  : Text(
                      '"${item.contentPreview}"',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(height: 1.5, fontStyle: FontStyle.italic),
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),

              // Tags
              if (item.tags.isNotEmpty) ...[
                const SizedBox(height: 10),
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
                          ))
                      .toList(),
                )
              ],

              // Botão de Remoção
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: theme.colorScheme.error.withOpacity(0.7),
                      size: 22),
                  tooltip: "Remover Destaque",
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
