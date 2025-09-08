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
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

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
                onBookSelected: (newBookAbbrev) {
                  // O callback onBookChanged já está aqui
                  onBookChanged(newBookAbbrev);
                },
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
                    booksMap?[selectedBook]?['nome'] ?? 'Selecionar Livro',
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
      child: Row(
        children: [
          // Botão de Capítulo Anterior
          IconButton(
            icon: Icon(Icons.chevron_left,
                color: theme.colorScheme.onSurface.withOpacity(0.7), size: 32),
            onPressed: onPreviousChapter,
            tooltip: "Capítulo Anterior",
            splashRadius: 24,
          ),

          // O novo botão seletor de livro
          // <<< INÍCIO DA MUDANÇA NO LAYOUT >>>
          // Agora são 3 botões expandidos no centro
          bookSelectorButton,
          const SizedBox(width: 8),
          versionSelectorButton, // Novo botão de versão
          const SizedBox(width: 8),
          Material(
            color: isStudyModeActive
                ? theme.colorScheme.primary
                    .withOpacity(0.15) // Cor quando ativo
                : theme.cardColor.withOpacity(0.15), // Cor quando inativo
            borderRadius: BorderRadius.circular(8),
            child: InkWell(
              onTap: onToggleStudyMode, // Chama a função que veio por parâmetro
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                child: Icon(
                  Icons.school_outlined,
                  color: isStudyModeActive
                      ? theme.colorScheme.primary // Cor do ícone quando ativo
                      : theme.colorScheme.onSurface
                          .withOpacity(0.7), // Cor quando inativo
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          if (selectedBook != null)
            Expanded(
              flex: 2, // Flex menor para o número do capítulo
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
          // Botão de Próximo Capítulo
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
