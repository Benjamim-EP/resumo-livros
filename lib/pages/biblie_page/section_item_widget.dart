// lib/pages/biblie_page/section_item_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart'; // Ainda necessário para despachar ação
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
  final bool isRead; // Parâmetro que vem do widget pai (_BiblePageState)

  const SectionItemWidget({
    super.key, // Chave do próprio SectionItemWidget
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
    required this.isRead, // Recebe o status de leitura do pai
  });

  @override
  State<SectionItemWidget> createState() => _SectionItemWidgetState();
}

class _SectionItemWidgetState extends State<SectionItemWidget>
    with AutomaticKeepAliveClientMixin {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoadingCommentary = false;

  @override
  bool get wantKeepAlive => true; // Para manter o estado do widget na ListView

  String get _sectionIdForTracking {
    // Garante que versesRangeStr não seja nulo ou vazio ao construir o ID
    final range =
        widget.versesRangeStr.isNotEmpty ? widget.versesRangeStr : "all";
    return "${widget.bookAbbrev}_c${widget.chapterNumber}_v$range";
  }

  String get _commentaryDocId {
    // Garante que versesRangeStr não seja nulo ou vazio ao construir o ID
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
        backgroundColor: Colors.transparent, // Para DraggableScrollableSheet
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
    super.build(context); // Necessário para AutomaticKeepAliveClientMixin
    final theme = Theme.of(context);
    final sectionId = _sectionIdForTracking;
    final bool currentIsRead = widget.isRead; // Usa o valor passado pelo pai

    // print("SectionItemWidget build: ${widget.sectionTitle}, isRead: $currentIsRead, sectionId: $sectionId");

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
                    // print("Botão Marcar Lido Pressionado para ${widget.sectionTitle}. Novo Status: ${!currentIsRead}");
                    StoreProvider.of<AppState>(context, listen: false).dispatch(
                      ToggleSectionReadStatusAction(
                        bookAbbrev: widget.bookAbbrev,
                        sectionId: sectionId, // Usa o ID calculado
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
              itemBuilder: (context, index) {
                final verseNumber = widget.verseNumbersInSection[index];
                dynamic verseDataItem;
                // Determina o sufixo da chave com base no tipo de tradução e também adiciona livro/capítulo
                // para garantir unicidade mesmo entre diferentes capítulos/livros com o mesmo verso e tradução
                String verseKeySuffix = widget.isHebrew
                    ? "hebrew_${widget.bookAbbrev}_${widget.chapterNumber}"
                    : "other_${widget.bookAbbrev}_${widget.chapterNumber}";

                if (widget.isHebrew) {
                  if (widget.allVerseDataInChapter
                          is List<List<Map<String, String>>> &&
                      verseNumber > 0 &&
                      verseNumber <=
                          (widget.allVerseDataInChapter as List).length) {
                    verseDataItem = (widget.allVerseDataInChapter
                        as List<List<Map<String, String>>>)[verseNumber - 1];
                  }
                } else {
                  if (widget.allVerseDataInChapter is List<String> &&
                      verseNumber > 0 &&
                      verseNumber <=
                          (widget.allVerseDataInChapter as List).length) {
                    verseDataItem = (widget.allVerseDataInChapter
                        as List<String>)[verseNumber - 1];
                  }
                }

                if (verseDataItem != null) {
                  return BiblePageWidgets.buildVerseItem(
                    // A chave aqui é para o widget específico do verso dentro desta seção
                    key: ValueKey<String>(
                        '${widget.bookAbbrev}_${widget.chapterNumber}_${verseNumber}_$verseKeySuffix'),
                    verseNumber: verseNumber,
                    verseData: verseDataItem,
                    selectedBook: widget.bookAbbrev,
                    selectedChapter: widget.chapterNumber,
                    context: context,
                    userHighlights: widget.userHighlights,
                    userNotes: widget.userNotes,
                    isHebrew: widget.isHebrew,
                  );
                } else {
                  // Isso pode acontecer se verseNumbersInSection tiver um número que não existe em allVerseDataInChapter
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
