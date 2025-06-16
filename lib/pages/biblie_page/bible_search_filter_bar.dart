// Em: lib/pages/biblie_page/bible_search_filter_bar.dart
import 'package:flutter/material.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';

typedef OnFilterChanged = void Function({
  String? testament,
  String? bookAbbrev,
  String? contentType,
});

class BibleSearchFilterBar extends StatefulWidget {
  final Map<String, dynamic>? initialBooksMap;
  final Map<String, dynamic> initialActiveFilters;
  final OnFilterChanged onFilterChanged;
  final VoidCallback onClearFilters;

  const BibleSearchFilterBar({
    super.key,
    this.initialBooksMap,
    required this.initialActiveFilters,
    required this.onFilterChanged,
    required this.onClearFilters,
  });

  @override
  State<BibleSearchFilterBar> createState() => _BibleSearchFilterBarState();
}

class _BibleSearchFilterBarState extends State<BibleSearchFilterBar> {
  String? _selectedTestament;
  String? _selectedBookAbbrev;
  String? _selectedType;
  Map<String, dynamic>? _booksMap;

  final List<Map<String, String>> _tiposDeConteudoDisponiveisParaFiltro = [
    {'value': 'biblia_comentario_secao', 'display': 'Comentário da Seção'},
    {'value': 'biblia_versiculos', 'display': 'Versículos Bíblicos'},
  ];

  @override
  void initState() {
    super.initState();
    _selectedTestament = widget.initialActiveFilters['testamento'] as String?;
    _selectedBookAbbrev = widget.initialActiveFilters['livro_curto'] as String?;
    _selectedType = widget.initialActiveFilters['tipo'] as String?;
    _booksMap = widget.initialBooksMap;

    if (_booksMap == null) {
      _loadBooksMapInternal();
    }
  }

  Future<void> _loadBooksMapInternal() async {
    final map = await BiblePageHelper.loadBooksMap();
    if (mounted) {
      setState(() {
        _booksMap = map;
      });
    }
  }

  // Helper para construir o botão de filtro com PopupMenuButton
  Widget _buildFilterPopupMenuButton<T>({
    required BuildContext context,
    required String currentLabel,
    required IconData icon,
    required T? currentValue,
    required List<PopupMenuEntry<T>> items,
    required ValueChanged<T?> onSelected,
    String? tooltip,
  }) {
    final theme = Theme.of(context);
    final bool isActive = currentValue != null;

    return PopupMenuButton<T>(
      tooltip: tooltip ?? "Selecionar ${currentLabel.toLowerCase()}",
      initialValue: currentValue,
      onSelected: onSelected,
      itemBuilder: (BuildContext context) => items,
      child: ActionChip(
        avatar: Icon(
          icon,
          size: 16,
          color: isActive
              ? theme.colorScheme.primary
              : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
        ),
        label: Text(
          currentLabel,
          style: TextStyle(
            fontSize: 12,
            color: isActive
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurfaceVariant,
          ),
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: isActive
            ? theme.colorScheme.primaryContainer.withOpacity(0.8)
            : theme.inputDecorationTheme.fillColor ??
                theme.cardColor.withOpacity(0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isActive
                ? theme.colorScheme.primaryContainer
                : theme.dividerColor.withOpacity(0.3),
            width: 0.8,
          ),
        ),
        elevation: isActive ? 1 : 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    List<String> testamentosDisponiveis = ["Antigo", "Novo"];

    // Itens para o PopupMenu de Testamento
    List<PopupMenuEntry<String?>> testamentMenuItems = [
      const PopupMenuItem<String?>(
        value: null,
        child: Text("Todos os Testamentos"),
      ),
      ...testamentosDisponiveis.map((String value) => PopupMenuItem<String?>(
            value: value,
            child: Text(value),
          )),
    ];

    // Itens para o PopupMenu de Livro
    List<PopupMenuEntry<String?>> bookMenuItems = [
      const PopupMenuItem<String?>(
        value: null,
        child: Text("Todos os Livros"),
      ),
    ];
    if (_booksMap != null && _booksMap!.isNotEmpty) {
      List<MapEntry<String, dynamic>> sortedBooks = _booksMap!.entries.toList()
        ..sort((a, b) =>
            (a.value['nome'] as String).compareTo(b.value['nome'] as String));
      for (var entry in sortedBooks) {
        // Filtra livros pelo testamento selecionado, se houver
        if (_selectedTestament == null ||
            entry.value['testament'] == _selectedTestament) {
          bookMenuItems.add(PopupMenuItem<String?>(
            value: entry.key,
            child: Text(entry.value['nome'] as String),
          ));
        }
      }
    }

    // Itens para o PopupMenu de Tipo de Conteúdo
    List<PopupMenuEntry<String?>> typeMenuItems = [
      const PopupMenuItem<String?>(
        value: null,
        child: Text("Todos os Tipos"),
      ),
      ..._tiposDeConteudoDisponiveisParaFiltro
          .map((tipoMap) => PopupMenuItem<String?>(
                value: tipoMap['value'],
                child: Text(tipoMap['display']!),
              )),
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          border: Border(
              bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.3), width: 0.5))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            _buildFilterPopupMenuButton<String?>(
              context: context,
              icon: Icons.menu_book_outlined,
              currentLabel: _selectedTestament ?? "Testamento",
              currentValue: _selectedTestament,
              items: testamentMenuItems,
              onSelected: (String? newValue) {
                setState(() {
                  _selectedTestament = newValue;
                  // Se o testamento mudou e o livro selecionado não pertence mais a ele, reseta o livro
                  if (_selectedBookAbbrev != null &&
                      _booksMap?[_selectedBookAbbrev]?['testament'] !=
                          _selectedTestament) {
                    _selectedBookAbbrev = null;
                  }
                });
                widget.onFilterChanged(
                    testament: _selectedTestament,
                    bookAbbrev: _selectedBookAbbrev,
                    contentType: _selectedType);
              },
            ),
            const SizedBox(width: 8),
            _buildFilterPopupMenuButton<String?>(
              context: context,
              icon: Icons.auto_stories_outlined,
              currentLabel: _selectedBookAbbrev != null
                  ? (_booksMap?[_selectedBookAbbrev]?['nome'] ?? "Livro")
                  : "Livro",
              currentValue: _selectedBookAbbrev,
              items: bookMenuItems, // Agora filtrado pelo testamento
              onSelected: (String? newValue) {
                setState(() => _selectedBookAbbrev = newValue);
                widget.onFilterChanged(
                    testament: _selectedTestament,
                    bookAbbrev: _selectedBookAbbrev,
                    contentType: _selectedType);
              },
            ),
            const SizedBox(width: 8),
            _buildFilterPopupMenuButton<String?>(
              context: context,
              icon: Icons.category_outlined,
              currentLabel: _selectedType != null
                  ? (_tiposDeConteudoDisponiveisParaFiltro.firstWhere(
                      (t) => t['value'] == _selectedType,
                      orElse: () => {'display': "Tipo"})['display']!)
                  : "Tipo",
              currentValue: _selectedType,
              items: typeMenuItems,
              onSelected: (String? newValue) {
                setState(() => _selectedType = newValue);
                widget.onFilterChanged(
                    testament: _selectedTestament,
                    bookAbbrev: _selectedBookAbbrev,
                    contentType: _selectedType);
              },
            ),
            if (_selectedTestament != null ||
                _selectedBookAbbrev != null ||
                _selectedType != null) ...[
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(Icons.clear_all_rounded,
                    size: 22, color: theme.colorScheme.error.withOpacity(0.8)),
                tooltip: "Limpar Filtros",
                onPressed: () {
                  setState(() {
                    _selectedTestament = null;
                    _selectedBookAbbrev = null;
                    _selectedType = null;
                  });
                  widget.onClearFilters();
                },
                splashRadius: 20,
                visualDensity: VisualDensity.compact,
              ),
            ]
          ],
        ),
      ),
    );
  }
}
