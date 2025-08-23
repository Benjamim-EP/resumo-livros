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
  bool _isDetailedView = true; // Começa na visão detalhada por padrão

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
      initialChildSize: 0.85,
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
              // --- Barra Superior com "Handle" e Botão de Alternância ---
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Center(
                        child: Container(
                          width: 40,
                          height: 5,
                          decoration: BoxDecoration(
                              color: theme.dividerColor,
                              borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: Icon(_isDetailedView
                          ? Icons.grid_view_outlined
                          : Icons.view_list_outlined),
                      tooltip: _isDetailedView
                          ? "Visão Compacta"
                          : "Visão Detalhada",
                      onPressed: () {
                        setState(() {
                          _isDetailedView = !_isDetailedView;
                        });
                      },
                    ),
                  ],
                ),
              ),

              // --- Abas (Antigo vs. Novo Testamento) ---
              TabBar(
                controller: _tabController,
                tabs: [
                  Tab(text: OLD_TESTAMENT_STRUCTURE.title),
                  Tab(text: NEW_TESTAMENT_STRUCTURE.title),
                ],
              ),

              // --- Conteúdo Principal ---
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

  // Widget para construir a visualização de um testamento
  Widget _buildTestamentView(BuildContext context, Testament testament,
      ScrollController scrollController) {
    if (_isDetailedView) {
      // --- Visão Detalhada (com categorias) ---
      return _buildDetailedTestamentView(context, testament, scrollController);
    } else {
      // --- Visão Compacta (grade de botões) ---
      return _buildCompactTestamentView(context, testament, scrollController);
    }
  }

  // Constrói a lista com seções e descrições
  Widget _buildDetailedTestamentView(BuildContext context, Testament testament,
      ScrollController scrollController) {
    final theme = Theme.of(context);
    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16.0),
      itemCount: testament.sections.length,
      itemBuilder: (context, index) {
        final section = testament.sections[index];
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
                      color:
                          theme.textTheme.bodySmall?.color?.withOpacity(0.7))),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: section.bookAbbrevs.map((bookAbbrev) {
                  return _buildBookButton(context, bookAbbrev);
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  // Constrói a grade simples com todos os botões
  Widget _buildCompactTestamentView(BuildContext context, Testament testament,
      ScrollController scrollController) {
    // Pega todos os livros do testamento em uma única lista
    final allBookAbbrevs =
        testament.sections.expand((s) => s.bookAbbrevs).toList();

    return GridView.builder(
      controller: scrollController,
      padding: const EdgeInsets.all(16.0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10.0,
        mainAxisSpacing: 10.0,
        childAspectRatio: 2.5,
      ),
      itemCount: allBookAbbrevs.length,
      itemBuilder: (context, index) {
        return _buildBookButton(context, allBookAbbrevs[index]);
      },
    );
  }

  // Widget reutilizável para o botão de cada livro
  Widget _buildBookButton(BuildContext context, String bookAbbrev) {
    final theme = Theme.of(context);
    final bookName =
        widget.booksMap[bookAbbrev]?['nome'] ?? bookAbbrev.toUpperCase();
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(
        bookName,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11.5),
      ),
    );
  }
}
