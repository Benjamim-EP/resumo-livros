// lib/pages/biblie_page/bible_navigation_controls.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/biblie_page/book_selection_modal.dart';
import 'package:septima_biblia/pages/biblie_page/utils.dart'; // Importa o Utils que tem os dropdowns

import 'package:flutter_redux/flutter_redux.dart';
import 'package:septima_biblia/redux/store.dart';

import 'package:septima_biblia/pages/biblie_page/bible_page_widgets.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';

class BibleNavigationControls extends StatelessWidget {
  final String? selectedBook;
  final int? selectedChapter;
  final Map<String, dynamic>? booksMap;
  final VoidCallback onPreviousChapter;
  final VoidCallback onNextChapter;
  final ValueChanged<String?> onBookChanged;
  final ValueChanged<int?> onChapterChanged;

  // <<< NOVO PARÂMETRO >>>
  final String selectedTranslation1;
  // <<< NOVO PARÂMETRO >>>
  final ValueChanged<String> onTranslation1Changed;
  final VoidCallback onToggleCompareMode;

  final bool isStudyModeActive;
  final VoidCallback onToggleStudyMode;

  final bool showHebrewInterlinear;
  final bool showGreekInterlinear;
  final VoidCallback onToggleHebrewInterlinear;
  final VoidCallback onToggleGreekInterlinear;

  const BibleNavigationControls({
    super.key,
    required this.selectedBook,
    required this.selectedChapter,
    required this.booksMap,
    required this.onPreviousChapter,
    required this.onNextChapter,
    required this.onBookChanged,
    required this.onChapterChanged,
    required this.selectedTranslation1, // <<< NOVO PARÂMETRO
    required this.onTranslation1Changed, // <<< NOVO PARÂMETRO
    required this.onToggleCompareMode,
    required this.isStudyModeActive,
    required this.onToggleStudyMode,
    required this.showHebrewInterlinear,
    required this.showGreekInterlinear,
    required this.onToggleHebrewInterlinear,
    required this.onToggleGreekInterlinear,
  });

  Widget _buildIconButton({
    required BuildContext context,
    required VoidCallback onPressed,
    required IconData icon,
    required bool isActive,
  }) {
    final theme = Theme.of(context);
    return Material(
      color: isActive
          ? theme.colorScheme.primary.withOpacity(0.15)
          : theme.cardColor.withOpacity(0.15),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          // Padding reduzido para um botão mais compacto
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Icon(
            icon,
            size: 22, // Ícone um pouco menor
            color: isActive
                ? theme.colorScheme.primary
                : theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final bool canShowHebrew =
        booksMap?[selectedBook]?['testament'] == 'Antigo';
    final bool canShowGreek = booksMap?[selectedBook]?['testament'] == 'Novo';

    // Widget customizado para o botão de seleção de livro
    Widget bookSelectorButton = Expanded(
      flex: 3,
      child: Material(
        color: theme.cardColor.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          onTap: () {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => BookSelectionModal(
                booksMap: booksMap!,
                currentlySelectedBook: selectedBook,
                onBookSelected: onBookChanged,
              ),
            );
          },
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    // Usa a abreviação em maiúsculas
                    selectedBook?.toUpperCase() ?? 'Livro',
                    style: TextStyle(
                      color: theme.colorScheme.onSurface,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Icon(Icons.arrow_drop_down,
                    color: theme.colorScheme.onSurface.withOpacity(0.7)),
              ],
            ),
          ),
        ),
      ),
    );

    // <<< NOVO WIDGET PARA O SELETOR DE VERSÃO >>>
    Widget versionSelectorButton = StoreConnector<AppState, bool>(
      converter: (store) =>
          store.state.subscriptionState.status ==
          SubscriptionStatus.premiumActive,
      builder: (context, isPremium) {
        return Expanded(
          flex: 2, // Flex menor para a sigla da versão
          child: Material(
            color: theme.cardColor.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: () {
                BiblePageWidgets.showTranslationSelection(
                  context: context,
                  selectedTranslation: selectedTranslation1,
                  onTranslationSelected: onTranslation1Changed,
                  currentSelectedBookAbbrev: selectedBook,
                  booksMap: booksMap,
                  isPremium: isPremium,
                  onToggleCompareMode: onToggleCompareMode,
                );
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                alignment: Alignment.center,
                child: Text(
                  selectedTranslation1.toUpperCase(),
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
          ),
        );
      },
    );

    return Padding(
      // Padding vertical reduzido
      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left,
                color: theme.colorScheme.onSurface.withOpacity(0.7), size: 30),
            onPressed: onPreviousChapter,
            tooltip: "Capítulo Anterior",
            splashRadius: 22, // Raio do splash menor
          ),

          bookSelectorButton,
          const SizedBox(width: 6), // Espaçamento reduzido

          versionSelectorButton,
          const SizedBox(width: 6), // Espaçamento reduzido

          _buildIconButton(
            context: context,
            onPressed: onToggleStudyMode,
            icon: Icons.school_outlined,
            isActive: isStudyModeActive,
          ),

          if (canShowHebrew) ...[
            const SizedBox(width: 6), // Espaçamento reduzido
            _buildIconButton(
              context: context,
              onPressed: onToggleHebrewInterlinear,
              icon: Icons.translate_rounded,
              isActive: showHebrewInterlinear,
            ),
          ],

          if (canShowGreek) ...[
            const SizedBox(width: 6), // Espaçamento reduzido
            _buildIconButton(
              context: context,
              onPressed: onToggleGreekInterlinear,
              icon: Icons.translate_rounded,
              isActive: showGreekInterlinear,
            ),
          ],

          const SizedBox(width: 6), // Espaçamento reduzido

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
                color: theme.colorScheme.onSurface.withOpacity(0.7), size: 30),
            onPressed: onNextChapter,
            tooltip: "Próximo Capítulo",
            splashRadius: 22, // Raio do splash menor
          ),
        ],
      ),
    );
  }
}
