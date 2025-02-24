import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/saveVerseDialog.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';

class BiblePageWidgets {
  /// Botão de seleção de tradução
  static Widget buildTranslationButton({
    required String translationKey,
    required String translationLabel,
    required String selectedTranslation,
    required VoidCallback onPressed,
    
  }) {
    final isSelected = selectedTranslation == translationKey;
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor:
            isSelected ? const Color(0xFFCDE7BE) : const Color(0xFF272828),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
      child: Text(
        translationLabel,
        style: TextStyle(
          color: isSelected ? const Color(0xFF181A1A) : Colors.white,
        ),
      ),
    );
  }

  /// Modal para selecionar a tradução
  static void showTranslationSelection({
    required BuildContext context,
    required String selectedTranslation,
    required Function(String) onTranslationSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF181A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Escolha a Tradução",
                style: TextStyle(color: Colors.white, fontSize: 18),
              ),
              const SizedBox(height: 16),
              buildTranslationButton(
                translationKey: 'nvi',
                translationLabel: 'NVI',
                selectedTranslation: selectedTranslation,
                onPressed: () {
                  onTranslationSelected('nvi');
                  Navigator.pop(context);
                },
              ),
              buildTranslationButton(
                translationKey: 'aa',
                translationLabel: 'AA',
                selectedTranslation: selectedTranslation,
                onPressed: () {
                  onTranslationSelected('aa');
                  Navigator.pop(context);
                },
              ),
              buildTranslationButton(
                translationKey: 'acf',
                translationLabel: 'ACF',
                selectedTranslation: selectedTranslation,
                onPressed: () {
                  onTranslationSelected('acf');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  /// Widget que exibe um versículo com comentários e opções
  static Widget buildVerseItem({
  required int verseNumber,
  required String verseText,
  required Map<int, List<Map<String, dynamic>>> verseComments,
  required String? selectedBook,
  required int? selectedChapter,
  required String selectedTranslation,
  required BuildContext context,
  required Map<String, dynamic>? booksMap,
  required Function(int) onAddUserComment, // 🔹 Adicionar este parâmetro
  required Function(int) onViewUserComments, // 🔹 Adicionar este parâmetro
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 4.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$verseNumber ',
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
            fontWeight: FontWeight.bold,
          ),
        ),
        Expanded(
          child: Text(
            verseText,
            style: const TextStyle(color: Colors.white70, fontSize: 16),
          ),
        ),
        if (verseComments.containsKey(verseNumber))
          IconButton(
            icon: const Icon(
              Icons.notes_rounded,
              color: Color(0xFFCDE7BE),
              size: 18,
            ),
            onPressed: () {
              UtilsBiblePage.showVerseComments(
                context: context,
                verseComments: verseComments,
                booksMap: booksMap,
                selectedBook: selectedBook,
                selectedChapter: selectedChapter,
                verseNumber: verseNumber,
                loadChapterContent: (book, chapter) =>
                    BiblePageHelper.loadChapterContent(
                        book, chapter, selectedTranslation),
                truncateString: (text, maxLength) => text.length > maxLength
                    ? '${text.substring(0, maxLength)}...'
                    : text,
              );
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        IconButton(
          icon: const Icon(
            Icons.bookmark_border,
            color: Colors.white70,
            size: 18,
          ),
          onPressed: () {
            showDialog(
              context: context,
              builder: (context) => SaveVerseDialog(
                bookAbbrev: selectedBook!,
                chapter: selectedChapter!,
                verseNumber: verseNumber,
              ),
            );
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        // 🔹 Botão para adicionar comentário do usuário
        IconButton(
          icon: const Icon(
            Icons.comment,
            color: Colors.white70,
            size: 18,
          ),
          onPressed: () {
            onAddUserComment(verseNumber);
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
        // 🔹 Botão para visualizar comentários do usuário
        IconButton(
          icon: const Icon(
            Icons.visibility,
            color: Colors.white70,
            size: 18,
          ),
          onPressed: () {
            onViewUserComments(verseNumber);
          },
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
        ),
      ],
    ),
  );
}
}
