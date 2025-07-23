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

    if (item.type == HighlightItemType.likedQuote) {
      // Frases curtidas podem, no futuro, abrir uma visualização especial.
      // Por enquanto, não fazem nada ao serem tocadas.
      return;
    }

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
    final bool isLikedQuote = item.type == HighlightItemType.likedQuote;

    final Color baseColor = _parseColor(
        item.colorHex, isVerse ? Colors.blue.shade700 : Colors.amber.shade700);
    final Color cardBackgroundColor = theme.cardColor;

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
      color: Colors.transparent,
      shadowColor: isLikedQuote
          ? Colors.black.withOpacity(0.4)
          : baseColor.withOpacity(0.2),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: isVerse ? null : () => _handleTap(context),
        splashColor: baseColor.withOpacity(0.1),
        highlightColor: baseColor.withOpacity(0.05),
        child: Container(
          decoration: isLikedQuote
              ? BoxDecoration(
                  image: DecorationImage(
                    image: NetworkImage(
                        "https://picsum.photos/seed/${item.id}/400/600"),
                    fit: BoxFit.cover,
                    colorFilter: ColorFilter.mode(
                      Colors.black.withOpacity(0.5),
                      BlendMode.darken,
                    ),
                  ),
                )
              : BoxDecoration(
                  gradient: LinearGradient(
                    colors: [baseColor.withOpacity(0.15), cardBackgroundColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    stops: const [0.0, 0.8],
                  ),
                ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isLikedQuote ? Icons.favorite : sourceIcon,
                      color:
                          isLikedQuote ? Colors.redAccent.shade100 : baseColor,
                      size: 22,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        item.referenceText,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: isLikedQuote ? Colors.white : baseColor,
                          shadows: isLikedQuote
                              ? [
                                  const Shadow(
                                      blurRadius: 2, color: Colors.black)
                                ]
                              : null,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        Icons.delete_outline,
                        color: isLikedQuote
                            ? Colors.white.withOpacity(0.7)
                            : theme.colorScheme.onSurface.withOpacity(0.5),
                        size: 22,
                      ),
                      tooltip:
                          isLikedQuote ? "Remover Curtida" : "Remover Destaque",
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      visualDensity: VisualDensity.compact,
                      onPressed: () {
                        final store =
                            StoreProvider.of<AppState>(context, listen: false);
                        if (isVerse) {
                          store.dispatch(ToggleHighlightAction(item.id));
                        } else if (isLikedQuote) {
                          print(
                              "Ação para descurtir a frase ${item.id} seria chamada aqui.");
                        } else {
                          store.dispatch(RemoveCommentHighlightAction(item.id));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // ===================================
                // <<< INÍCIO DA LÓGICA ATUALIZADA >>>
                // ===================================
                if (isVerse)
                  FutureBuilder<String>(
                    future: item.originalData['fullVerseTextFuture']
                        as Future<String>?,
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))),
                        );
                      }
                      if (snapshot.hasError ||
                          !snapshot.hasData ||
                          snapshot.data!.isEmpty) {
                        return Text(
                          item.contentPreview, // Usa o preview como fallback em caso de erro
                          style: theme.textTheme.bodyMedium?.copyWith(
                            height: 1.5,
                            fontStyle: FontStyle.italic,
                            color: theme.colorScheme.error,
                          ),
                          maxLines: 10,
                          overflow: TextOverflow.ellipsis,
                        );
                      }
                      // Se carregou com sucesso
                      return Text(
                        snapshot.data!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.5,
                          color: theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.85),
                        ),
                        maxLines: 10,
                        overflow: TextOverflow.ellipsis,
                      );
                    },
                  )
                else
                  // Lógica para literatura e frases curtidas (que já têm o texto)
                  Text(
                    '"${item.contentPreview}"',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.5,
                      fontStyle: FontStyle.italic,
                      color: isLikedQuote
                          ? Colors.white.withOpacity(0.9)
                          : theme.textTheme.bodyMedium?.color
                              ?.withOpacity(0.85),
                      shadows: isLikedQuote
                          ? [const Shadow(blurRadius: 2, color: Colors.black)]
                          : null,
                    ),
                    maxLines: isLikedQuote ? 6 : 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                // ===================================
                // <<< FIM DA LÓGICA ATUALIZADA >>>
                // ===================================

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
