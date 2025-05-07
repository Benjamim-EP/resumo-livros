// lib/pages/biblie_page/section_item_widget.dart
import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_widgets.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/section_commentary_modal.dart';
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart'; // Importe o serviço

class SectionItemWidget extends StatefulWidget {
  final String sectionTitle;
  final List<int>
      verseNumbersInSection; // Números dos versos na seção (ex: [1,2,3,4,5])
  final List<String>
      allVerseTextsInChapter; // Todos os textos dos versos do capítulo
  final String bookSlug; // e.g., "genesis" (para ID do Firestore)
  final String bookAbbrev; // e.g., "gn" (para salvar versículo)
  final int chapterNumber;
  final String versesRangeStr; // e.g., "1-5" (para ID do Firestore)
  final Map<String, String> userHighlights;
  final Map<String, String> userNotes;

  const SectionItemWidget({
    Key? key,
    required this.sectionTitle,
    required this.verseNumbersInSection,
    required this.allVerseTextsInChapter,
    required this.bookSlug,
    required this.bookAbbrev,
    required this.chapterNumber,
    required this.versesRangeStr,
    required this.userHighlights,
    required this.userNotes,
  }) : super(key: key);

  @override
  State<SectionItemWidget> createState() => _SectionItemWidgetState();
}

class _SectionItemWidgetState extends State<SectionItemWidget> {
  final FirestoreService _firestoreService = FirestoreService();
  bool _isLoadingCommentary = false;

  String _generateCommentaryDocId() {
    // ID: {book_slug}_c{chapter}_v{verses_range_str}
    return "${widget.bookSlug}_c${widget.chapterNumber}_v${widget.versesRangeStr}";
  }

  Future<void> _showCommentary(BuildContext context) async {
    setState(() {
      _isLoadingCommentary = true;
    });

    final commentaryDocId = _generateCommentaryDocId();
    final commentaryData =
        await _firestoreService.getSectionCommentary(commentaryDocId);

    setState(() {
      _isLoadingCommentary = false;
    });

    if (context.mounted) {
      if (commentaryData != null && commentaryData['commentary'] is List) {
        final List<Map<String, dynamic>> commentaryItems =
            List<Map<String, dynamic>>.from(commentaryData['commentary']);

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => SectionCommentaryModal(
            sectionTitle: widget.sectionTitle,
            commentaryItems: commentaryItems,
          ),
        );
      } else {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => SectionCommentaryModal(
            sectionTitle: widget.sectionTitle,
            commentaryItems: const [],
          ),
        );
      }
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
                      fontWeight: FontWeight.bold,
                    ),
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
                if (verseNumber > 0 &&
                    verseNumber <= widget.allVerseTextsInChapter.length) {
                  final verseText =
                      widget.allVerseTextsInChapter[verseNumber - 1];
                  return BiblePageWidgets.buildVerseItem(
                    verseNumber: verseNumber,
                    verseText: verseText,
                    selectedBook: widget.bookAbbrev,
                    selectedChapter: widget.chapterNumber,
                    context: context,
                    // <<< Passando os dados do Redux >>>
                    userHighlights: widget.userHighlights,
                    userNotes: widget.userNotes,
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
