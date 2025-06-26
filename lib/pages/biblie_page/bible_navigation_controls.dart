// lib/pages/biblie_page/bible_navigation_controls.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/biblie_page/utils.dart'; // Importa o Utils que tem os dropdowns

class BibleNavigationControls extends StatelessWidget {
  final String? selectedBook;
  final int? selectedChapter;
  final Map<String, dynamic>? booksMap;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final ValueChanged<String?> onBookChanged;
  final ValueChanged<int?> onChapterChanged;

  const BibleNavigationControls({
    super.key,
    required this.selectedBook,
    required this.selectedChapter,
    required this.booksMap,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onBookChanged,
    required this.onChapterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left,
                color: theme.colorScheme.onSurface.withOpacity(0.7), size: 32),
            onPressed: onPreviousChapter,
            tooltip: "Capítulo Anterior",
            splashRadius: 24,
          ),
          Expanded(
            flex: 3,
            child: UtilsBiblePage.buildBookDropdown(
              context: context,
              selectedBook: selectedBook,
              booksMap: booksMap,
              onChanged: onBookChanged,
              iconColor: theme.colorScheme.onSurface.withOpacity(0.7),
              textColor: theme.colorScheme.onSurface,
              backgroundColor: theme.cardColor.withOpacity(0.15),
            ),
          ),
          const SizedBox(width: 8),
          if (selectedBook != null)
            Expanded(
              flex: 2,
              child: UtilsBiblePage.buildChapterDropdown(
                context: context,
                selectedChapter: selectedChapter,
                booksMap: booksMap,
                selectedBook: selectedBook,
                onChanged: onChapterChanged,
                iconColor: theme.colorScheme.onSurface.withOpacity(0.7),
                textColor: theme.colorScheme.onSurface,
                backgroundColor: theme.cardColor.withOpacity(0.15),
              ),
            ),
          IconButton(
            icon: Icon(Icons.chevron_right,
                color: theme.colorScheme.onSurface.withOpacity(0.7), size: 32),
            onPressed: onNextChapter,
            tooltip: "Próximo Capítulo",
            splashRadius: 24,
          ),
        ],
      ),
    );
  }
}
