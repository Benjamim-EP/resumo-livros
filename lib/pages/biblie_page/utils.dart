import 'package:flutter/material.dart';
// REMOVIDO: import 'package:flutter_markdown/flutter_markdown.dart';
// REMOVIDO: import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';

class UtilsBiblePage {
  // ... (buildChapterDropdown e buildBookDropdown permanecem iguais) ...
  static Widget buildChapterDropdown({
    required int? selectedChapter,
    required Map<String, dynamic>? booksMap,
    required String? selectedBook,
    required Function(int?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedChapter,
          hint: const Text(
            'Capítulo',
            style: TextStyle(color: Colors.white),
          ),
          dropdownColor: const Color(0xFF272828),
          isExpanded: true,
          items: selectedBook != null &&
                  booksMap != null &&
                  booksMap[selectedBook] != null &&
                  booksMap[selectedBook]['capitulos'] != null
              ? List.generate(
                  booksMap[selectedBook]['capitulos']
                      as int, // Adicionada verificação de null
                  (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                )
              : [], // Retorna lista vazia se algo for nulo
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        ),
      ),
    );
  }

  static Widget buildBookDropdown({
    required String? selectedBook,
    required Map<String, dynamic>? booksMap,
    required Function(String?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF272828),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedBook,
          hint: const Text(
            'Selecione um Livro',
            style: TextStyle(color: Colors.white),
          ),
          dropdownColor: const Color(0xFF272828),
          isExpanded: true,
          items: booksMap?.entries.map((entry) {
                // Usar .entries para iterar sobre chave/valor
                final abbrev = entry.key;
                final bookData =
                    entry.value as Map<String, dynamic>; // Cast para mapa
                final bookName =
                    bookData['nome'] ?? 'Desconhecido'; // Acessar 'nome'
                return DropdownMenuItem<String>(
                  value: abbrev,
                  child: Text(
                    bookName,
                    style: const TextStyle(color: Colors.white),
                  ),
                );
              }).toList() ??
              [], // Retorna lista vazia se booksMap for nulo
          onChanged: onChanged,
          icon: const Icon(Icons.arrow_drop_down, color: Colors.white),
        ),
      ),
    );
  }

  // REMOVIDO: Função showVerseComments inteira
  // REMOVIDO: Função showGeneralComments inteira
  // REMOVIDO: Função _sortCommentsByTags inteira (era usada por showVerseComments)
  // REMOVIDO: Função _buildModalHeader inteira (era usada por showVerseComments)
  // REMOVIDO: Função _buildCommentsList inteira (era usada por showVerseComments e showGeneralComments)
}
