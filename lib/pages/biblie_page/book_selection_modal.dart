// lib/pages/biblie_page/book_selection_modal.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/consts/bible_structure.dart';

class BookSelectionModal extends StatefulWidget {
  final Map<String, dynamic> booksMap;
  final String? currentlySelectedBook;
  final Function(String) onBookSelected;

  const BookSelectionModal({
    super.key,
    required this.booksMap,
    this.currentlySelectedBook,
    required this.onBookSelected,
  });

  @override
  State<BookSelectionModal> createState() => _BookSelectionModalState();
}

class _BookSelectionModalState extends State<BookSelectionModal>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    int initialTabIndex = 0;
    if (widget.currentlySelectedBook != null) {
      final testament =
          widget.booksMap[widget.currentlySelectedBook]?['testament'];
      if (testament == 'Novo') {
        initialTabIndex = 1;
      }
    }
    _tabController =
        TabController(length: 2, vsync: this, initialIndex: initialTabIndex);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return DraggableScrollableSheet(
      initialChildSize: 0.85, // Um pouco maior para caber as descrições
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: theme.dialogBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // "Handle" e Abas
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(10))),
              ),
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: OLD_TESTAMENT_STRUCTURE.title),
                  Tab(text: NEW_TESTAMENT_STRUCTURE.title),
                ],
              ),
              // Conteúdo
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTestamentView(
                        context, OLD_TESTAMENT_STRUCTURE, scrollController),
                    _buildTestamentView(
                        context, NEW_TESTAMENT_STRUCTURE, scrollController),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Novo widget para construir a visualização de um testamento inteiro
  Widget _buildTestamentView(BuildContext context, Testament testament,
      ScrollController scrollController) {
    final theme = Theme.of(context);
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: testament.sections.length + 1, // +1 para o cabeçalho
      itemBuilder: (context, index) {
        // O primeiro item é o cabeçalho descritivo do testamento
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child:
                Text(testament.description, style: theme.textTheme.bodyMedium),
          );
        }

        // Os itens seguintes são as seções (Pentateuco, etc.)
        final section = testament.sections[index - 1];
        return _buildSectionWidget(context, section);
      },
    );
  }

  // Novo widget para construir uma seção de livros (ex: Pentateuco)
  Widget _buildSectionWidget(BuildContext context, BibleSection section) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(section.title,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(section.description,
              style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7))),
          const SizedBox(height: 12),
          // Grid de livros para esta seção
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3, // 3 livros por linha
              crossAxisSpacing: 10.0,
              mainAxisSpacing: 10.0,
              childAspectRatio: 2.5, // Botões mais largos
            ),
            itemCount: section.bookAbbrevs.length,
            itemBuilder: (context, index) {
              final bookAbbrev = section.bookAbbrevs[index];
              final bookName = widget.booksMap[bookAbbrev]?['nome'] ??
                  bookAbbrev.toUpperCase();
              final isSelected = bookAbbrev == widget.currentlySelectedBook;

              return FilledButton(
                onPressed: () {
                  widget.onBookSelected(bookAbbrev);
                  Navigator.pop(context);
                },
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  backgroundColor: isSelected
                      ? theme.colorScheme.primary
                      : theme.colorScheme.surfaceVariant,
                  foregroundColor: isSelected
                      ? theme.colorScheme.onPrimary
                      : theme.colorScheme.onSurfaceVariant,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  bookName,
                  textAlign: TextAlign.center,
                  style:
                      const TextStyle(fontSize: 11.5), // Fonte menor para caber
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
