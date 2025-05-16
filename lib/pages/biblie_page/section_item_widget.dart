// lib/pages/biblie_page/section_item_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart'; // Para StoreConnector
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_progress_actions.dart'; // Nossas novas ações
import 'package:resumo_dos_deuses_flutter/redux/store.dart'; // Para AppState
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_widgets.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/section_commentary_modal.dart';
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart'; // Ainda pode ser usado para commentary
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';

class SectionItemWidget extends StatefulWidget {
  final String sectionTitle;
  final List<int> verseNumbersInSection;
  final dynamic allVerseDataInChapter;
  final String bookSlug; // Usado para ID do comentário
  final String bookAbbrev; // Usado para Redux e ID de progresso
  final int chapterNumber;
  final String versesRangeStr; // Usado para ID de progresso e comentário
  final Map<String, String>
      userHighlights; // Mantido para destaques de versículos
  final Map<String, String> userNotes; // Mantido para notas de versículos
  final bool isHebrew;

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
  });

  @override
  State<SectionItemWidget> createState() => _SectionItemWidgetState();
}

class _SectionItemWidgetState extends State<SectionItemWidget> {
  final FirestoreService _firestoreService =
      FirestoreService(); // Para buscar comentários
  bool _isLoadingCommentary = false;

  // ID da seção para rastreamento de leitura e comentários
  String get _sectionIdForTracking {
    return "${widget.bookAbbrev}_c${widget.chapterNumber}_v${widget.versesRangeStr}";
  }

  // ID do documento de comentário (pode ser diferente se bookSlug for usado)
  String get _commentaryDocId {
    // Mantém a lógica original se o ID do comentário usa bookSlug
    return "${widget.bookSlug}_c${widget.chapterNumber}_v${widget.versesRangeStr}";
  }

  Future<void> _showCommentary(BuildContext context) async {
    if (!mounted) return;
    setState(() => _isLoadingCommentary = true);

    final commentaryData =
        await _firestoreService.getSectionCommentary(_commentaryDocId);
    String bookFullName = widget.bookAbbrev.toUpperCase();
    try {
      final booksMap =
          await BiblePageHelper.loadBooksMap(); // Este é o booksMap geral
      if (booksMap.containsKey(widget.bookAbbrev)) {
        bookFullName = booksMap[widget.bookAbbrev]?['nome'] ?? bookFullName;
      }
    } catch (e) {
      print("Erro ao carregar nome do livro em SectionItemWidget: $e");
    }

    if (mounted) {
      // Verifica mounted novamente após awaits
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
          bookSlug: widget
              .bookSlug, // Passa o slug original para o modal de comentário
          bookName: bookFullName,
          chapterNumber: widget.chapterNumber,
          versesRangeStr: widget.versesRangeStr,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sectionId = _sectionIdForTracking; // Usa o getter

    return StoreConnector<AppState, bool>(
      // Conecta ao estado para saber se esta seção foi lida
      converter: (store) {
        // Acessa o UserState para o progresso de leitura
        final bookProgress =
            store.state.userState.readSectionsByBook[widget.bookAbbrev];
        return bookProgress?.contains(sectionId) ?? false;
      },
      distinct: true, // Só reconstrói se o valor de 'isRead' mudar
      builder: (context, isRead) {
        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          // Muda a cor de fundo se a seção foi lida
          color:
              isRead ? theme.primaryColor.withOpacity(0.10) : theme.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: isRead // Adiciona uma borda sutil se lido
                ? BorderSide(
                    color: theme.primaryColor.withOpacity(0.4), width: 1)
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
                            color: isRead
                                ? theme.primaryColor
                                : theme.colorScheme
                                    .primary, // Destaque no título se lido
                            fontSize: 18,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                    // Botão para marcar/desmarcar como lido
                    IconButton(
                      icon: Icon(
                        isRead
                            ? Icons.check_circle
                            : Icons.check_circle_outline,
                        color: isRead
                            ? theme.primaryColor
                            : theme.iconTheme.color?.withOpacity(0.7),
                        size: 26,
                      ),
                      tooltip:
                          isRead ? "Marcar como não lido" : "Marcar como lido",
                      onPressed: () {
                        StoreProvider.of<AppState>(context, listen: false)
                            .dispatch(
                          ToggleSectionReadStatusAction(
                            bookAbbrev: widget.bookAbbrev,
                            sectionId: sectionId,
                            markAsRead: !isRead, // Inverte o status atual
                          ),
                        );
                      },
                    ),
                    _isLoadingCommentary
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: Padding(
                              // Adiciona padding ao CircularProgressIndicator
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

                    if (widget.isHebrew) {
                      if (widget.allVerseDataInChapter
                              is List<List<Map<String, String>>> &&
                          verseNumber > 0 &&
                          verseNumber <=
                              (widget.allVerseDataInChapter as List).length) {
                        verseDataItem = (widget.allVerseDataInChapter as List<
                            List<Map<String, String>>>)[verseNumber - 1];
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
      },
    );
  }
}
