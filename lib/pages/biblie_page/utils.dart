// lib/pages/biblie_page/utils.dart
import 'package:flutter/material.dart';

class UtilsBiblePage {
  static Widget buildChapterDropdown({
    required BuildContext context, // <<< ADICIONAR CONTEXT
    required int? selectedChapter,
    required Map<String, dynamic>? booksMap,
    required String? selectedBook,
    required Function(int?) onChanged,
    Color? iconColor,
    Color? textColor,
    Color? backgroundColor,
  }) {
    final theme = Theme.of(context); // <<< OBTER TEMA DO CONTEXTO PASSADO

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: selectedChapter,
          hint: Text(
            'Cap.',
            style: TextStyle(
                color:
                    textColor ?? theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 13), // Ajuste de fontSize
          ),
          dropdownColor: theme.dialogBackgroundColor,
          isExpanded: true,
          items: selectedBook != null &&
                  booksMap != null &&
                  booksMap[selectedBook] != null &&
                  booksMap[selectedBook]['capitulos'] != null
              ? List.generate(
                  booksMap[selectedBook]['capitulos'] as int,
                  (index) => DropdownMenuItem<int>(
                    value: index + 1,
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                          color: textColor ?? theme.colorScheme.onSurface,
                          fontSize: 14),
                    ),
                  ),
                )
              : [],
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down,
              color: iconColor ?? theme.colorScheme.onSurface.withOpacity(0.7)),
          style: TextStyle(
              color: textColor ?? theme.colorScheme.onSurface, fontSize: 14),
        ),
      ),
    );
  }

  static Widget buildBookDropdown({
    required BuildContext context, // <<< ADICIONAR CONTEXT
    required String? selectedBook,
    required Map<String, dynamic>? booksMap,
    required Function(String?) onChanged,
    Color? iconColor,
    Color? textColor,
    Color? backgroundColor,
  }) {
    final theme = Theme.of(context); // <<< OBTER TEMA DO CONTEXTO PASSADO

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selectedBook,
          hint: Text(
            'Livro',
            style: TextStyle(
                color:
                    textColor ?? theme.colorScheme.onSurface.withOpacity(0.7),
                fontSize: 13), // Ajuste de fontSize
          ),
          dropdownColor: theme.dialogBackgroundColor,
          isExpanded: true,
          items: booksMap?.entries.map((entry) {
                final abbrev = entry.key;
                final bookData = entry.value as Map<String, dynamic>;
                final bookName = bookData['nome'] ?? 'Desconhecido';
                return DropdownMenuItem<String>(
                  value: abbrev,
                  child: Text(
                    bookName,
                    style: TextStyle(
                        color: textColor ?? theme.colorScheme.onSurface,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList() ??
              [],
          onChanged: onChanged,
          icon: Icon(Icons.arrow_drop_down,
              color: iconColor ?? theme.colorScheme.onSurface.withOpacity(0.7)),
          selectedItemBuilder: (BuildContext context) {
            if (booksMap == null) return [];
            return booksMap.entries.map<Widget>((entry) {
              final bookData = entry.value as Map<String, dynamic>;
              final bookName = bookData['nome'] ?? 'Desconhecido';
              return Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  // Adiciona um pequeno padding para o item selecionado
                  padding: const EdgeInsets.symmetric(vertical: 2.0),
                  child: Text(
                    bookName,
                    style: TextStyle(
                        color: textColor ?? theme.colorScheme.onSurface,
                        fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              );
            }).toList();
          },
          // Removido style daqui, pois selectedItemBuilder cuida do estilo do item selecionado
          // e o style dos itens no dropdown é definido no DropdownMenuItem
        ),
      ),
    );
  }
}
