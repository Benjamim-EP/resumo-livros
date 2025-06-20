// lib/pages/biblie_page/section_item_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/actions/bible_progress_actions.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_widgets.dart';
import 'package:septima_biblia/pages/biblie_page/section_commentary_modal.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart'; // Para BiblePageHelper.loadBooksMap() se necessário para nome

class SectionItemWidget extends StatefulWidget {
  final String sectionTitle;
  final List<int> verseNumbersInSection;
  final dynamic
      allVerseDataInChapter; // Pode ser List<String> ou List<List<Map<String, String>>>
  final String bookSlug;
  final String bookAbbrev;
  final int chapterNumber;
  final String versesRangeStr;
  final Map<String, String> userHighlights;
  final Map<String, String> userNotes;
  final bool isHebrew;
  final bool isGreekInterlinear; // <<< NOVO
  final bool isRead;
  final bool showHebrewInterlinear;
  final bool showGreekInterlinear; // <<< NOVO
  final List<List<Map<String, String>>>? hebrewInterlinearSectionData;
  final List<List<Map<String, String>>>?
      greekInterlinearSectionData; // <<< NOVO
  final double fontSizeMultiplier; // <<< NOVO

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
    this.isGreekInterlinear = false, // <<< NOVO
    required this.isRead,
    required this.showHebrewInterlinear,
    required this.showGreekInterlinear, // <<< NOVO
    this.hebrewInterlinearSectionData,
    this.greekInterlinearSectionData, // <<< NOVO
    required this.fontSizeMultiplier,
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
    final range = widget.versesRangeStr.isNotEmpty
        ? widget.versesRangeStr
        : "all_verses_in_section"; // Fallback se range for vazio
    // ***** ALTERAÇÃO AQUI *****
    // Usar bookAbbrev em vez de bookSlug para corresponder ao ID do Firestore
    String abbrevForFirestore = widget.bookAbbrev;
    if (widget.bookAbbrev.toLowerCase() == 'job') {
      abbrevForFirestore = 'jó'; // Usa 'jó' para buscar no Firestore
    }
    return "${abbrevForFirestore}_c${widget.chapterNumber}_v$range";
    // Exemplo: "1co_c10_v1-5"
  }

  Future<void> _showCommentary(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isLoadingCommentary = true);

    print(
        "Tentando carregar comentário para Doc ID: $_commentaryDocId"); // Log para debug

    final commentaryData =
        await _firestoreService.getSectionCommentary(_commentaryDocId);
    // ... resto da função _showCommentary permanece igual
    // ... (verificação de null, extração de commentaryItems, chamada do Modal)
    String bookFullName = widget.bookAbbrev.toUpperCase();
    try {
      final booksMap = await BiblePageHelper.loadBooksMap();
      if (booksMap.containsKey(widget.bookAbbrev)) {
        bookFullName = booksMap[widget.bookAbbrev]?['nome'] ?? bookFullName;
      }
    } catch (e) {
      print(
          "Erro ao carregar nome do livro em SectionItemWidget para comentário: $e");
    }

    if (mounted) {
      setState(() => _isLoadingCommentary = false);
      final List<Map<String, dynamic>> commentaryItems =
          (commentaryData != null && commentaryData['commentary'] is List)
              ? List<Map<String, dynamic>>.from(commentaryData['commentary'])
              : const [];

      if (commentaryItems.isEmpty && commentaryData == null) {
        print(
            "Nenhum dado de comentário encontrado para $_commentaryDocId ou documento não existe.");
      } else if (commentaryItems.isEmpty && commentaryData != null) {
        print(
            "Documento $_commentaryDocId encontrado, mas o array 'commentary' está vazio ou não existe.");
      }

      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => SectionCommentaryModal(
          sectionTitle: commentaryData?['title'] ?? widget.sectionTitle,
          commentaryItems: commentaryItems,
          bookAbbrev: widget.bookAbbrev,
          bookSlug: widget.bookSlug,
          bookName: bookFullName,
          chapterNumber: widget.chapterNumber,
          versesRangeStr: widget.versesRangeStr,
          initialFontSizeMultiplier:
              widget.fontSizeMultiplier, // <<< PASSA O MULTIPLICADOR
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Necessário para AutomaticKeepAliveClientMixin
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
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
                        width: 40,
                        height: 40,
                        alignment: Alignment.center,
                        child: const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        ))
                    : IconButton(
                        icon: Icon(
                          Icons.comment_outlined,
                          color: theme.iconTheme.color?.withOpacity(0.7),
                          size: 22,
                        ),
                        tooltip: "Ver Comentário da Seção",
                        onPressed: () => _showCommentary(context),
                        splashRadius: 20,
                        padding: const EdgeInsets.all(8),
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
                final verseNumber = widget.verseNumbersInSection[indexInSecao];
                dynamic mainTranslationVerseDataItem;
                List<Map<String, String>>? hebrewDataForThisVerse;
                List<Map<String, String>>? greekDataForThisVerse; // <<< NOVO

                // Determina o dado da tradução principal
                if (widget.isGreekInterlinear) {
                  // <<< SE FOR GREGO INTERLINEAR PRINCIPAL
                  if (widget.allVerseDataInChapter
                          is List<List<Map<String, String>>> &&
                      verseNumber > 0 &&
                      verseNumber <=
                          (widget.allVerseDataInChapter as List).length) {
                    mainTranslationVerseDataItem = (widget.allVerseDataInChapter
                        as List<List<Map<String, String>>>)[verseNumber - 1];
                  }
                } else if (widget.isHebrew) {
                  if (widget.allVerseDataInChapter
                          is List<List<Map<String, String>>> &&
                      verseNumber > 0 &&
                      verseNumber <=
                          (widget.allVerseDataInChapter as List).length) {
                    mainTranslationVerseDataItem = (widget.allVerseDataInChapter
                        as List<List<Map<String, String>>>)[verseNumber - 1];
                  }
                } else {
                  // Tradução normal (string)
                  if (widget.allVerseDataInChapter is List<String> &&
                      verseNumber > 0 &&
                      verseNumber <=
                          (widget.allVerseDataInChapter as List).length) {
                    mainTranslationVerseDataItem = (widget.allVerseDataInChapter
                        as List<String>)[verseNumber - 1];
                  }
                }

                // Determina dados para interlinear complementar HEBRAICO
                if (widget.showHebrewInterlinear &&
                    !widget
                        .isHebrew && // Só mostra se não for a tradução principal
                    widget.hebrewInterlinearSectionData != null &&
                    indexInSecao <
                        widget.hebrewInterlinearSectionData!.length) {
                  hebrewDataForThisVerse =
                      widget.hebrewInterlinearSectionData![indexInSecao];
                }

                // Determina dados para interlinear complementar GREGO
                if (widget.showGreekInterlinear &&
                    !widget
                        .isGreekInterlinear && // Só mostra se não for a tradução principal
                    widget.greekInterlinearSectionData != null &&
                    indexInSecao < widget.greekInterlinearSectionData!.length) {
                  greekDataForThisVerse =
                      widget.greekInterlinearSectionData![indexInSecao];
                }

                String verseKeySuffix = widget.isHebrew
                    ? "hebrew"
                    : (widget.isGreekInterlinear ? "greek" : "other");
                if (widget.showHebrewInterlinear &&
                    hebrewDataForThisVerse != null) {
                  verseKeySuffix += "_heb_interlinear";
                }
                if (widget.showGreekInterlinear &&
                    greekDataForThisVerse != null) {
                  verseKeySuffix += "_grk_interlinear";
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
                    isGreekInterlinear:
                        widget.isGreekInterlinear, // <<< PASSANDO
                    showHebrewInterlinear:
                        widget.showHebrewInterlinear && !widget.isHebrew,
                    showGreekInterlinear: widget.showGreekInterlinear &&
                        !widget.isGreekInterlinear, // <<< PASSANDO
                    hebrewVerseData: hebrewDataForThisVerse,
                    greekVerseData: greekDataForThisVerse, // <<< PASSANDO
                    fontSizeMultiplier: widget.fontSizeMultiplier,
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text(
                        'Erro: Verso $verseNumber não encontrado nos dados do capítulo para esta seção.',
                        style: TextStyle(color: theme.colorScheme.error)),
                  );
                }
              },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: Material(
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
                  borderRadius: BorderRadius.circular(20),
                  splashColor: theme.primaryColor.withOpacity(0.3),
                  highlightColor: theme.primaryColor.withOpacity(0.15),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          currentIsRead
                              ? Icons.check_circle
                              : Icons.check_circle_outline,
                          color: currentIsRead
                              ? theme.primaryColor
                              : theme.iconTheme.color?.withOpacity(0.8),
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          currentIsRead ? "Lido" : "Marcar como Lido",
                          style: TextStyle(
                            color: currentIsRead
                                ? theme.primaryColor
                                : theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.9),
                            fontSize: 13,
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
