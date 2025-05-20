// lib/pages/biblie_page/section_item_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_widgets.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/section_commentary_modal.dart';
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';

class SectionItemWidget extends StatefulWidget {
  final String sectionTitle;
  final List<int> verseNumbersInSection;
  final dynamic allVerseDataInChapter;
  final String bookSlug;
  final String bookAbbrev;
  final int chapterNumber;
  final String versesRangeStr;
  final Map<String, String> userHighlights;
  final Map<String, String> userNotes;
  final bool isHebrew;
  final bool isRead;
  final bool showHebrewInterlinear;
  final List<List<Map<String, String>>>? hebrewInterlinearSectionData;

  const SectionItemWidget({
    super.key,
    required this.sectionTitle,
    required this.verseNumbersInSection,
    required this.allVerseDataInChapter,
    required this.bookSlug,
    required this.bookAbbrev,
    required this.chapterNumber,
    required this.versesRangeStr,
    required this.userHighlights,
    required this.userNotes,
    this.isHebrew = false,
    required this.isRead,
    required this.showHebrewInterlinear,
    this.hebrewInterlinearSectionData,
  });

  @override
  State<SectionItemWidget> createState() => _SectionItemWidgetState();
}

class _SectionItemWidgetState extends State<SectionItemWidget>
    with AutomaticKeepAliveClientMixin {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoadingCommentary = false;

  @override
  bool get wantKeepAlive => true;

  String get _sectionIdForTracking {
    final range =
        widget.versesRangeStr.isNotEmpty ? widget.versesRangeStr : "all";
    return "${widget.bookAbbrev}_c${widget.chapterNumber}_v$range";
  }

  String get _commentaryDocId {
    final range =
        widget.versesRangeStr.isNotEmpty ? widget.versesRangeStr : "all";
    return "${widget.bookSlug}_c${widget.chapterNumber}_v$range";
  }

  Future<void> _showCommentary(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isLoadingCommentary = true);

    final commentaryData =
        await _firestoreService.getSectionCommentary(_commentaryDocId);
    String bookFullName = widget.bookAbbrev.toUpperCase();
    try {
      final booksMap = await BiblePageHelper.loadBooksMap();
      if (booksMap.containsKey(widget.bookAbbrev)) {
        bookFullName = booksMap[widget.bookAbbrev]?['nome'] ?? bookFullName;
      }
    } catch (e) {
      print("Erro ao carregar nome do livro em SectionItemWidget: $e");
    }

    if (mounted) {
      setState(() => _isLoadingCommentary = false);
      final List<Map<String, dynamic>> commentaryItems =
          (commentaryData != null && commentaryData['commentary'] is List)
              ? List<Map<String, dynamic>>.from(commentaryData['commentary'])
              : const [];
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SectionCommentaryModal(
          sectionTitle: widget.sectionTitle,
          commentaryItems: commentaryItems,
          bookAbbrev: widget.bookAbbrev,
          bookSlug: widget.bookSlug,
          bookName: bookFullName,
          chapterNumber: widget.chapterNumber,
          versesRangeStr: widget.versesRangeStr,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final theme = Theme.of(context);
    final sectionId = _sectionIdForTracking;
    final bool currentIsRead = widget.isRead;

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: currentIsRead
          ? theme.primaryColor.withOpacity(0.10)
          : theme.cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: currentIsRead
            ? BorderSide(color: theme.primaryColor.withOpacity(0.4), width: 1)
            : BorderSide.none,
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Linha do Título e Botão de Comentário ---
            Row(
              crossAxisAlignment:
                  CrossAxisAlignment.start, // Alinha o topo dos itens
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(
                        top:
                            8.0), // Ajuste para alinhar melhor com o IconButton
                    child: Text(
                      widget.sectionTitle,
                      style: TextStyle(
                          color: currentIsRead
                              ? theme.primaryColor
                              : theme.colorScheme.primary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                _isLoadingCommentary
                    ? Container(
                        // Container para dar tamanho ao CircularProgressIndicator
                        width: 40, // Largura similar ao IconButton
                        height: 40, // Altura similar ao IconButton
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 20, // Tamanho do indicador
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ))
                    : IconButton(
                        icon: Icon(
                          Icons.comment_outlined,
                          color: theme.iconTheme.color?.withOpacity(0.7),
                          size: 22, // Tamanho do ícone
                        ),
                        tooltip: "Ver Comentário da Seção",
                        onPressed: () => _showCommentary(context),
                        splashRadius: 20, // Raio do splash
                        padding:
                            const EdgeInsets.all(8), // Padding interno do botão
                      ),
              ],
            ),
            Divider(color: theme.dividerColor.withOpacity(0.5)),
            const SizedBox(height: 8),
            // --- Lista de Versículos ---
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.verseNumbersInSection.length,
              itemBuilder: (context, indexInSecao) {
                final verseNumber = widget.verseNumbersInSection[indexInSecao];
                dynamic mainTranslationVerseDataItem;
                List<Map<String, String>>? hebrewDataForThisVerse;

                if (widget.isHebrew) {
                  if (widget.allVerseDataInChapter
                          is List<List<Map<String, String>>> &&
                      verseNumber > 0 &&
                      verseNumber <=
                          (widget.allVerseDataInChapter as List).length) {
                    mainTranslationVerseDataItem = (widget.allVerseDataInChapter
                        as List<List<Map<String, String>>>)[verseNumber - 1];
                  }
                } else {
                  if (widget.allVerseDataInChapter is List<String> &&
                      verseNumber > 0 &&
                      verseNumber <=
                          (widget.allVerseDataInChapter as List).length) {
                    mainTranslationVerseDataItem = (widget.allVerseDataInChapter
                        as List<String>)[verseNumber - 1];
                  }
                }

                if (widget.showHebrewInterlinear &&
                    !widget.isHebrew &&
                    widget.hebrewInterlinearSectionData != null &&
                    indexInSecao <
                        widget.hebrewInterlinearSectionData!.length) {
                  hebrewDataForThisVerse =
                      widget.hebrewInterlinearSectionData![indexInSecao];
                }

                String verseKeySuffix = widget.isHebrew ? "hebrew" : "other";
                if (widget.showHebrewInterlinear &&
                    hebrewDataForThisVerse != null) {
                  verseKeySuffix += "_interlinear";
                }

                if (mainTranslationVerseDataItem != null) {
                  return BiblePageWidgets.buildVerseItem(
                    key: ValueKey<String>(
                        '${widget.bookAbbrev}_${widget.chapterNumber}_${verseNumber}_$verseKeySuffix'),
                    verseNumber: verseNumber,
                    verseData: mainTranslationVerseDataItem,
                    selectedBook: widget.bookAbbrev,
                    selectedChapter: widget.chapterNumber,
                    context: context,
                    userHighlights: widget.userHighlights,
                    userNotes: widget.userNotes,
                    isHebrew: widget.isHebrew,
                    showHebrewInterlinear:
                        widget.showHebrewInterlinear && !widget.isHebrew,
                    hebrewVerseData: hebrewDataForThisVerse,
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                        'Erro: Verso $verseNumber não encontrado nos dados do capítulo.',
                        style: TextStyle(color: theme.colorScheme.error)),
                  );
                }
              },
            ),
            // --- Botão Marcar como Lido (Movido para Baixo) ---
            const SizedBox(height: 12), // Espaçamento acima do botão
            Align(
              alignment: Alignment.centerRight, // Alinha o botão à direita
              child: Material(
                // Material para efeito de tinta no InkWell
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    StoreProvider.of<AppState>(context, listen: false).dispatch(
                      ToggleSectionReadStatusAction(
                        bookAbbrev: widget.bookAbbrev,
                        sectionId: sectionId,
                        markAsRead: !currentIsRead,
                      ),
                    );
                  },
                  borderRadius:
                      BorderRadius.circular(20), // Raio da borda para o InkWell
                  splashColor: theme.primaryColor.withOpacity(0.3),
                  highlightColor: theme.primaryColor.withOpacity(0.15),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6), // Padding interno
                    child: Row(
                      mainAxisSize: MainAxisSize
                          .min, // Para o Row ocupar apenas o espaço necessário
                      children: [
                        Icon(
                          currentIsRead
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          color: currentIsRead
                              ? theme.primaryColor
                              : theme.iconTheme.color?.withOpacity(0.8),
                          size: 20, // Tamanho menor para o ícone
                        ),
                        const SizedBox(width: 6),
                        Text(
                          currentIsRead ? "Lido" : "Marcar como Lido",
                          style: TextStyle(
                            color: currentIsRead
                                ? theme.primaryColor
                                : theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.9),
                            fontSize: 13, // Tamanho menor para o texto
                            fontWeight: currentIsRead
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
