import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/saveVerseDialog.dart';
// REMOVIDO: import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';

class BiblePageWidgets {
  // ... (buildTranslationButton e showTranslationSelection permanecem iguais) ...
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

  /// Widget que exibe um versículo (sem comentários)
  static Widget buildVerseItem({
    required int verseNumber,
    required String verseText,
    // REMOVIDO: verseComments
    required String? selectedBook,
    required int? selectedChapter,
    // REMOVIDO: selectedTranslation (não é mais necessário aqui)
    required BuildContext context,
    // REMOVIDO: booksMap (não é mais necessário aqui)
    // REMOVIDO: onAddUserComment
    // REMOVIDO: onViewUserComments
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
          // REMOVIDO: Ícone e lógica de exibição de comentários do Firestore
          // REMOVIDO: Ícone e lógica de comentários do usuário (adicionar/visualizar)

          // Mantém o botão de salvar versículo
          IconButton(
            icon: const Icon(
              Icons.bookmark_border,
              color: Colors.white70,
              size: 18,
            ),
            onPressed: () {
              if (selectedBook != null && selectedChapter != null) {
                showDialog(
                  context: context,
                  builder: (context) => SaveVerseDialog(
                    bookAbbrev: selectedBook,
                    chapter: selectedChapter,
                    verseNumber: verseNumber,
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text("Selecione livro e capítulo para salvar.")));
              }
            },
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}
