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
  final List<int>
      verseNumbersInSection; // Lista dos números dos versos desta seção (ex: [1,2,3,4,5])
  final dynamic
      allVerseDataInChapter; // Dados da tradução principal para o capítulo inteiro
  final String bookSlug;
  final String bookAbbrev;
  final int chapterNumber;
  final String versesRangeStr;
  final Map<String, String> userHighlights;
  final Map<String, String> userNotes;
  final bool
      isHebrew; // Indica se a TRADUÇÃO PRINCIPAL (allVerseDataInChapter) é hebraica
  final bool isRead;

  // NOVOS PARÂMETROS PARA INTERLINEAR
  final bool showHebrewInterlinear;
  // Dados hebraicos para TODOS os versos DESTA SEÇÃO, se showHebrewInterlinear for true.
  // Cada item na lista externa corresponde a um versículo da seção.
  // Cada item na lista interna (List<Map<String, String>>) são as palavras hebraicas daquele versículo.
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
    required this.showHebrewInterlinear, // NOVO
    this.hebrewInterlinearSectionData, // NOVO (pode ser null se showHebrewInterlinear for false)
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
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
                IconButton(
                  icon: Icon(
                    currentIsRead
                        ? Icons.check_circle
                        : Icons.check_circle_outline,
                    color: currentIsRead
                        ? theme.primaryColor
                        : theme.iconTheme.color?.withOpacity(0.7),
                    size: 26,
                  ),
                  tooltip: currentIsRead
                      ? "Marcar como não lido"
                      : "Marcar como lido",
                  onPressed: () {
                    StoreProvider.of<AppState>(context, listen: false).dispatch(
                      ToggleSectionReadStatusAction(
                        bookAbbrev: widget.bookAbbrev,
                        sectionId: sectionId,
                        markAsRead: !currentIsRead,
                      ),
                    );
                  },
                ),
                _isLoadingCommentary
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: Padding(
                          padding: EdgeInsets.all(4.0),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ))
                    : IconButton(
                        icon: Icon(Icons.comment_outlined,
                            color: theme.iconTheme.color?.withOpacity(0.7)),
                        tooltip: "Ver Comentário da Seção",
                        onPressed: () => _showCommentary(context),
                      ),
              ],
            ),
            Divider(color: theme.dividerColor.withOpacity(0.5)),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.verseNumbersInSection.length,
              itemBuilder: (context, indexInSecao) {
                // index na lista de versos da seção
                final verseNumber = widget.verseNumbersInSection[indexInSecao];
                dynamic mainTranslationVerseDataItem; // Para NVI, ACF, etc.
                List<Map<String, String>>?
                    hebrewDataForThisVerse; // Para o interlinear

                // Pega o dado da tradução principal
                if (widget.isHebrew) {
                  // Se a tradução principal FOR hebraico
                  if (widget.allVerseDataInChapter
                          is List<List<Map<String, String>>> &&
                      verseNumber > 0 &&
                      verseNumber <=
                          (widget.allVerseDataInChapter as List).length) {
                    mainTranslationVerseDataItem = (widget.allVerseDataInChapter
                        as List<List<Map<String, String>>>)[verseNumber - 1];
                  }
                } else {
                  // Se a tradução principal NÃO FOR hebraico (ex: NVI)
                  if (widget.allVerseDataInChapter is List<String> &&
                      verseNumber > 0 &&
                      verseNumber <=
                          (widget.allVerseDataInChapter as List).length) {
                    mainTranslationVerseDataItem = (widget.allVerseDataInChapter
                        as List<String>)[verseNumber - 1];
                  }
                }

                // Pega os dados hebraicos para o interlinear, se showHebrewInterlinear for true
                // E a tradução principal NÃO for o hebraico original
                if (widget.showHebrewInterlinear &&
                    !widget
                        .isHebrew && // Só mostra interlinear se a principal não for já o hebraico
                    widget.hebrewInterlinearSectionData != null &&
                    indexInSecao <
                        widget.hebrewInterlinearSectionData!.length) {
                  // hebrewInterlinearSectionData é uma lista de versos, cada verso é uma lista de palavras.
                  // O indexInSecao corresponde ao índice do verso DENTRO desta seção.
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
                    verseData:
                        mainTranslationVerseDataItem, // Texto da tradução principal
                    selectedBook: widget.bookAbbrev,
                    selectedChapter: widget.chapterNumber,
                    context: context,
                    userHighlights: widget.userHighlights,
                    userNotes: widget.userNotes,
                    isHebrew: widget.isHebrew, // Se a VIEW PRINCIPAL é hebraica
                    // NOVOS PARÂMETROS PARA O INTERLINEAR
                    showHebrewInterlinear: widget.showHebrewInterlinear &&
                        !widget
                            .isHebrew, // Só mostra se a principal não for hebraico
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
          ],
        ),
      ),
    );
  }
}
