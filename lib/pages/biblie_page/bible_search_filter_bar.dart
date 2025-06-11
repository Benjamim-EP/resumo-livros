// lib/pages/biblie_page/bible_search_filter_bar.dart
import 'package:flutter/material.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart'; // Para carregar booksMap se necessário aqui

// Defina os tipos de callback que o widget pai precisará fornecer
typedef OnFilterChanged = void Function({
  String? testament,
  String? bookAbbrev,
  String? contentType,
});

class BibleSearchFilterBar extends StatefulWidget {
  final Map<String, dynamic>? initialBooksMap; // Passar o booksMap carregado
  final Map<String, dynamic> initialActiveFilters;
  final OnFilterChanged onFilterChanged;
  final VoidCallback onClearFilters; // Callback para limpar filtros

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

  // Seus tipos de conteúdo (pode vir de uma constante também)
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

  // Função auxiliar para construir os botões de filtro (copiada da BiblePage)
  Widget _buildFilterChipButton({
    required BuildContext context,
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isActive = false,
  }) {
    final theme = Theme.of(context);
    return ActionChip(
      avatar: Icon(
        icon,
        size: 16,
        color: isActive
            ? theme.colorScheme.onPrimaryContainer
            : theme.colorScheme.onSurfaceVariant.withOpacity(0.7),
      ),
      label: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          color: isActive
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
        overflow: TextOverflow.ellipsis,
      ),
      onPressed: onPressed,
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
    );
  }

  // Função para mostrar o BottomSheet de seleção (copiada da BiblePage)
  Future<T?> _showFilterSelectionSheet<T>({
    required BuildContext context,
    required String title,
    required List<DropdownMenuItem<T>> items,
    required T? currentValue,
    required ValueChanged<T?>
        onChangedCallback, // Renomeado para evitar conflito
  }) {
    final theme = Theme.of(context);
    return showModalBottomSheet<T>(
      context: context,
      backgroundColor: theme.dialogBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext modalContext) {
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: theme.textTheme.titleLarge
                    ?.copyWith(color: theme.colorScheme.onSurface),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<T>(
                value: currentValue,
                items: items,
                onChanged: (T? newValue) {
                  onChangedCallback(newValue); // Usa o callback passado
                  Navigator.pop(modalContext);
                },
                decoration: InputDecoration(
                  filled: true,
                  fillColor: theme.inputDecorationTheme.fillColor ??
                      theme.cardColor.withOpacity(0.1),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                dropdownColor: theme.dialogBackgroundColor,
                style: TextStyle(
                    color: theme.textTheme.bodyLarge?.color, fontSize: 14),
                iconEnabledColor: theme.iconTheme.color,
                isExpanded: true,
              ),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    List<String> testamentosDisponiveis = ["Antigo", "Novo"];

    List<DropdownMenuItem<String>> bookDropdownItems = [
      DropdownMenuItem<String>(
          value: null,
          child: Text("Todos os Livros",
              style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)))),
    ];
    if (_booksMap != null && _booksMap!.isNotEmpty) {
      List<MapEntry<String, dynamic>> sortedBooks = _booksMap!.entries.toList()
        ..sort((a, b) =>
            (a.value['nome'] as String).compareTo(b.value['nome'] as String));
      for (var entry in sortedBooks) {
        bookDropdownItems.add(DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value['nome'] as String,
              style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
        ));
      }
    }

    List<DropdownMenuItem<String>> typeDropdownItems = [
      DropdownMenuItem<String>(
          value: null,
          child: Text("Todos os Tipos",
              style: TextStyle(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7)))),
    ];
    for (var tipoMap in _tiposDeConteudoDisponiveisParaFiltro) {
      typeDropdownItems.add(DropdownMenuItem<String>(
        value: tipoMap['value'],
        child: Text(tipoMap['display']!,
            style: TextStyle(color: theme.textTheme.bodyLarge?.color)),
      ));
    }

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
            _buildFilterChipButton(
              context: context,
              icon: Icons.menu_book_outlined,
              label: _selectedTestament ?? "Testamento",
              isActive: _selectedTestament != null,
              onPressed: () {
                _showFilterSelectionSheet<String>(
                  context: context,
                  title: "Selecionar Testamento",
                  items: [
                    DropdownMenuItem<String>(
                        value: null,
                        child: Text("Todos os Testamentos",
                            style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color
                                    ?.withOpacity(0.7)))),
                    ...testamentosDisponiveis.map((String value) =>
                        DropdownMenuItem<String>(
                            value: value,
                            child: Text(value,
                                style: TextStyle(
                                    color: theme.textTheme.bodyLarge?.color)))),
                  ],
                  currentValue: _selectedTestament,
                  onChangedCallback: (String? newValue) {
                    // Renomeado aqui
                    setState(() => _selectedTestament = newValue);
                    widget.onFilterChanged(
                        testament: newValue,
                        bookAbbrev: _selectedBookAbbrev,
                        contentType: _selectedType);
                  },
                );
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChipButton(
              context: context,
              icon: Icons.auto_stories_outlined,
              label: _selectedBookAbbrev != null
                  ? (_booksMap?[_selectedBookAbbrev]?['nome'] ?? "Livro")
                  : "Livro",
              isActive: _selectedBookAbbrev != null,
              onPressed: () {
                _showFilterSelectionSheet<String>(
                  context: context,
                  title: "Selecionar Livro",
                  items: bookDropdownItems,
                  currentValue: _selectedBookAbbrev,
                  onChangedCallback: (String? newValue) {
                    // Renomeado aqui
                    setState(() => _selectedBookAbbrev = newValue);
                    widget.onFilterChanged(
                        testament: _selectedTestament,
                        bookAbbrev: newValue,
                        contentType: _selectedType);
                  },
                );
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChipButton(
              context: context,
              icon: Icons.category_outlined,
              label: _selectedType != null
                  ? (_tiposDeConteudoDisponiveisParaFiltro.firstWhere(
                      (t) => t['value'] == _selectedType,
                      orElse: () => {'display': "Tipo"})['display']!)
                  : "Tipo",
              isActive: _selectedType != null,
              onPressed: () {
                _showFilterSelectionSheet<String>(
                  context: context,
                  title: "Selecionar Tipo de Conteúdo",
                  items: typeDropdownItems,
                  currentValue: _selectedType,
                  onChangedCallback: (String? newValue) {
                    // Renomeado aqui
                    setState(() => _selectedType = newValue);
                    widget.onFilterChanged(
                        testament: _selectedTestament,
                        bookAbbrev: _selectedBookAbbrev,
                        contentType: newValue);
                  },
                );
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
                  widget.onClearFilters(); // Chama o callback do pai
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
