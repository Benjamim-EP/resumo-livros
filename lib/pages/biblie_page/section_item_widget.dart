// lib/pages/biblie_page/section_item_widget.dart
import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_widgets.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/section_commentary_modal.dart';
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';

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
  final bool isHebrew; // Novo: Indica se a tradução atual é hebraico

  const SectionItemWidget({
    super.key,
    required this.sectionTitle,
    required this.verseNumbersInSection,
    required this.allVerseDataInChapter, // Nome alterado para clareza
    required this.bookSlug,
    required this.bookAbbrev,
    required this.chapterNumber,
    required this.versesRangeStr,
    required this.userHighlights,
    required this.userNotes,
    this.isHebrew = false, // Novo: Padrão para false
  });

  @override
  State<SectionItemWidget> createState() => _SectionItemWidgetState();
}

class _SectionItemWidgetState extends State<SectionItemWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoadingCommentary = false;

  String _generateCommentaryDocId() {
    return "${widget.bookSlug}_c${widget.chapterNumber}_v${widget.versesRangeStr}";
  }

  Future<void> _showCommentary(BuildContext context) async {
    setState(() => _isLoadingCommentary = true);
    final commentaryDocId = _generateCommentaryDocId();
    final commentaryData =
        await _firestoreService.getSectionCommentary(commentaryDocId);
    String bookFullName = widget.bookAbbrev.toUpperCase();
    try {
      final booksMap = await BiblePageHelper.loadBooksMap();
      if (booksMap.containsKey(widget.bookAbbrev)) {
        bookFullName = booksMap[widget.bookAbbrev]?['nome'] ?? bookFullName;
      }
    } catch (e) {
      print("Erro ao carregar nome do livro em SectionItemWidget: $e");
    }
    setState(() => _isLoadingCommentary = false);

    if (context.mounted) {
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
    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: const Color(0xFF272828),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    widget.sectionTitle,
                    style: const TextStyle(
                        color: Color(0xFFCDE7BE),
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                ),
                _isLoadingCommentary
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : IconButton(
                        icon: const Icon(Icons.comment_outlined,
                            color: Color(0xFFCDE7BE)),
                        tooltip: "Ver Comentário da Seção",
                        onPressed: () => _showCommentary(context),
                      ),
              ],
            ),
            const Divider(color: Colors.white30),
            const SizedBox(height: 8),
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.verseNumbersInSection.length,
              itemBuilder: (context, index) {
                final verseNumber = widget.verseNumbersInSection[index];
                dynamic
                    verseDataItem; // Pode ser String ou List<Map<String, String>>

                // Acessa o dado do verso corretamente
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
                    verseNumber: verseNumber,
                    verseData: verseDataItem,
                    selectedBook: widget.bookAbbrev,
                    selectedChapter: widget.chapterNumber,
                    context: context,
                    userHighlights: widget.userHighlights,
                    userNotes: widget.userNotes,
                    isHebrew: widget.isHebrew, // Passa a flag
                  );
                } else {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4.0),
                    child: Text('Erro: Verso $verseNumber inválido na seção.',
                        style: const TextStyle(color: Colors.redAccent)),
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
