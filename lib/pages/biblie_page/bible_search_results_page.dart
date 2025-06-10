// lib/pages/biblie_page/bible_search_results_page.dart
import 'dart:convert'; // Para json.decode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para rootBundle
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:resumo_dos_deuses_flutter/redux/reducers.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_search_actions.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart'; // Para SetInitialBibleLocationAction, RequestBottomNavChangeAction
import 'package:resumo_dos_deuses_flutter/services/firestore_service.dart';

class BibleSearchResultsPage extends StatefulWidget {
  final String initialQuery;
  const BibleSearchResultsPage({super.key, required this.initialQuery});

  @override
  State<BibleSearchResultsPage> createState() => _BibleSearchResultsPageState();
}

class _BibleSearchResultsPageState extends State<BibleSearchResultsPage> {
  late TextEditingController _queryController;
  Map<String, dynamic> _localBooksMap = {};
  String? _selectedTestament;
  String? _selectedBookAbbrev;
  String? _selectedType;

  String? _expandedItemId;
  String? _loadedExpandedContent;
  bool _isLoadingExpandedContent = false;

  final FirestoreService _firestoreService = FirestoreService();

  final List<Map<String, String>> _tiposDeConteudoDisponiveis = [
    {'value': 'biblia_comentario_secao', 'display': 'Comentário da Seção'},
    {'value': 'biblia_versiculos', 'display': 'Versículos Bíblicos'},
  ];

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _loadBooksMapForDropdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final store = StoreProvider.of<AppState>(context, listen: false);
        final initialFilters = store.state.bibleSearchState.activeFilters;
        setState(() {
          _selectedTestament = initialFilters['testamento'] as String?;
          _selectedBookAbbrev = initialFilters['livro_curto'] as String?;
          _selectedType = initialFilters['tipo'] as String?;
        });
        // Se a query inicial não estiver vazia e os resultados estiverem vazios, dispara a busca
        if (widget.initialQuery.isNotEmpty &&
            store.state.bibleSearchState.results.isEmpty) {
          _applyFiltersAndSearch(context);
        }
      }
    });
  }

  Future<void> _loadBooksMapForDropdown() async {
    final map = await BiblePageHelper.loadBooksMap();
    if (mounted) setState(() => _localBooksMap = map);
  }

  void _applyFiltersAndSearch(BuildContext context) {
    final store = StoreProvider.of<AppState>(context, listen: false);
    store
        .dispatch(SetBibleSearchFilterAction('testamento', _selectedTestament));
    store.dispatch(
        SetBibleSearchFilterAction('livro_curto', _selectedBookAbbrev));
    store.dispatch(SetBibleSearchFilterAction('tipo', _selectedType));
    final queryToSearch = _queryController.text.trim();
    if (queryToSearch.isNotEmpty) {
      store.dispatch(SearchBibleSemanticAction(queryToSearch));
    } else if (store.state.bibleSearchState.currentQuery.isNotEmpty) {
      store.dispatch(
          SearchBibleSemanticAction(store.state.bibleSearchState.currentQuery));
    } else {
      print("Nenhuma query para buscar após aplicar filtros.");
      store.dispatch(SearchBibleSemanticSuccessAction(
          [])); // Limpa resultados se não houver query
    }
  }

  void _clearAllFilters(BuildContext context) {
    final store = StoreProvider.of<AppState>(context, listen: false);
    setState(() {
      _selectedTestament = null;
      _selectedBookAbbrev = null;
      _selectedType = null;
    });
    store.dispatch(ClearBibleSearchFiltersAction());
    final queryToSearch = _queryController.text.trim();
    if (queryToSearch.isNotEmpty) {
      store.dispatch(SearchBibleSemanticAction(queryToSearch));
    } else if (store.state.bibleSearchState.currentQuery.isNotEmpty) {
      store.dispatch(
          SearchBibleSemanticAction(store.state.bibleSearchState.currentQuery));
    } else {
      print("Nenhuma query para buscar após limpar filtros.");
      store.dispatch(SearchBibleSemanticSuccessAction([]));
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<String> _fetchDetailedContent(
      Map<String, dynamic> metadata, String itemId) async {
    final tipo = metadata['tipo'] as String?;
    final bookAbbrev = metadata['livro_curto'] as String?;
    final chapterStr = metadata['capitulo']?.toString();
    final versesRange = metadata['versiculos'] as String?;

    if (tipo == 'biblia_versiculos' &&
        bookAbbrev != null &&
        chapterStr != null &&
        versesRange != null) {
      try {
        final List<String> versesContent = [];
        final chapterData = await BiblePageHelper.loadChapterDataComparison(
          bookAbbrev,
          int.parse(chapterStr),
          'nvi', // Tradução padrão para exibição
          null,
        );

        final List<dynamic>? nviVerseList = chapterData['verseData']?['nvi'];

        if (nviVerseList != null && nviVerseList is List<String>) {
          List<int> verseNumbersToLoad = [];
          if (versesRange.contains('-')) {
            final parts = versesRange.split('-');
            final start = int.tryParse(parts[0]);
            final end = int.tryParse(parts[1]);
            if (start != null && end != null && start <= end) {
              for (int i = start; i <= end; i++) {
                verseNumbersToLoad.add(i);
              }
            }
          } else {
            final singleVerse = int.tryParse(versesRange);
            if (singleVerse != null) {
              verseNumbersToLoad.add(singleVerse);
            }
          }

          if (verseNumbersToLoad.isEmpty)
            return "Intervalo de versículos inválido: $versesRange";

          for (int vn in verseNumbersToLoad) {
            if (vn > 0 && vn <= nviVerseList.length) {
              versesContent.add("**$vn** ${nviVerseList[vn - 1]}");
            } else {
              versesContent.add("**$vn** [Texto não disponível]");
            }
          }
        }
        return versesContent.isNotEmpty
            ? versesContent.join("\n\n")
            : "Texto dos versículos não encontrado para $bookAbbrev $chapterStr:$versesRange.";
      } catch (e) {
        print(
            "Erro ao carregar versículos para $itemId ($bookAbbrev $chapterStr:$versesRange): $e");
        return "Erro ao carregar versículos.";
      }
    } else if (tipo == 'biblia_comentario_secao') {
      final commentaryDocId = itemId.endsWith('_bc')
          ? itemId.substring(0, itemId.length - 3)
          : itemId;
      try {
        final commentaryData =
            await _firestoreService.getSectionCommentary(commentaryDocId);
        if (commentaryData != null && commentaryData['commentary'] is List) {
          final List<dynamic> comments = commentaryData['commentary'];
          if (comments.isEmpty)
            return "Nenhum comentário disponível para esta seção.";
          return comments
              .map((c) =>
                  (c['traducao'] as String?)?.trim() ??
                  (c['original'] as String?)?.trim() ??
                  "")
              .where((text) => text.isNotEmpty)
              .join("\n\n---\n\n");
        }
        return "Comentário não encontrado para a seção: $commentaryDocId";
      } catch (e) {
        print(
            "Erro ao carregar comentário para $itemId (docId: $commentaryDocId): $e");
        return "Erro ao carregar comentário.";
      }
    }
    return "Tipo de conteúdo desconhecido ou dados insuficientes para carregar detalhes.";
  }

  void _toggleItemExpansion(
      Map<String, dynamic> metadata, String itemId) async {
    if (_expandedItemId == itemId) {
      setState(() {
        _expandedItemId = null;
        _loadedExpandedContent = null;
      });
    } else {
      setState(() {
        _expandedItemId = itemId;
        _isLoadingExpandedContent = true;
        _loadedExpandedContent = null;
      });
      final content = await _fetchDetailedContent(metadata, itemId);
      if (mounted && _expandedItemId == itemId) {
        setState(() {
          _loadedExpandedContent = content;
          _isLoadingExpandedContent = false;
        });
      } else if (mounted && _expandedItemId != itemId) {
        // Se outro item foi selecionado enquanto este carregava, não atualiza o conteúdo
        // mas para o loading se ainda estiver ativo para o itemId original.
        if (_isLoadingExpandedContent && _expandedItemId == null) {
          // Verifica se o loading era para o item que não é mais o expandido
          setState(() => _isLoadingExpandedContent = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor,
        iconTheme: theme.appBarTheme.iconTheme,
        title: TextField(
            controller: _queryController,
            decoration: InputDecoration(
                hintText: 'Buscar na Bíblia...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.7))),
            style: TextStyle(
                color: theme.textTheme.titleLarge?.color ??
                    theme.colorScheme.onSurface),
            onSubmitted: (query) {
              if (query.trim().isNotEmpty) {
                _applyFiltersAndSearch(context);
              }
            }),
        actions: [
          IconButton(
            icon: Icon(Icons.search,
                color: theme.appBarTheme.actionsIconTheme?.color ??
                    theme.colorScheme.onPrimary),
            onPressed: () {
              if (_queryController.text.trim().isNotEmpty) {
                _applyFiltersAndSearch(context);
              }
            },
          )
        ],
      ),
      body: StoreConnector<AppState, BibleSearchState>(
        converter: (store) => store.state.bibleSearchState,
        builder: (context, state) {
          return Column(
            children: [
              _buildFilterWidgets(context, state.activeFilters),
              if (state.isLoading && state.results.isEmpty)
                const Expanded(
                    child: Center(child: CircularProgressIndicator())),
              if (!state.isLoading && state.error != null)
                Expanded(
                    child: Center(
                        child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Erro: ${state.error}",
                      style: TextStyle(color: theme.colorScheme.error)),
                ))),
              if (!state.isLoading &&
                  state.error == null &&
                  state.results.isEmpty &&
                  _queryController.text.isNotEmpty)
                Expanded(
                    child: Center(
                        child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                      "Nenhum resultado encontrado para '${_queryController.text}'.",
                      style: theme.textTheme.bodyMedium),
                ))),
              if (state.results.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: state.results.length,
                    itemBuilder: (context, index) {
                      final item = state.results[index];
                      final itemId =
                          item['id'] as String? ?? 'unknown_id_$index';
                      Map<String, dynamic> metadata = {};
                      final rawMetadata = item['metadata'];
                      if (rawMetadata is Map) {
                        metadata = Map<String, dynamic>.from(rawMetadata.map(
                            (key, value) => MapEntry(key.toString(), value)));
                      }

                      final tipoResultado = metadata['tipo'] as String?;
                      String? commentaryTitle =
                          metadata['titulo_comentario'] as String?;
                      final reference =
                          "${metadata['livro_completo'] ?? metadata['livro_curto'] ?? '?'} ${metadata['capitulo'] ?? '?'}:${metadata['versiculos'] ?? '?'}";
                      final score = item['score'] as double?;
                      final bool isExpanded = _expandedItemId == itemId;

                      String previewContent = "Toque para ver detalhes";
                      if (tipoResultado == 'biblia_comentario_secao') {
                        previewContent =
                            commentaryTitle ?? "Ver comentário da seção...";
                      } else if (tipoResultado == 'biblia_versiculos') {
                        previewContent = "Ver versículos...";
                      }

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        color: theme.cardColor,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ListTile(
                              title: Text(reference,
                                  style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color:
                                          theme.textTheme.titleLarge?.color)),
                              subtitle: Text(previewContent,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: theme.textTheme.bodyMedium?.color
                                          ?.withOpacity(0.7))),
                              trailing: Icon(
                                  isExpanded
                                      ? Icons.expand_less
                                      : Icons.expand_more,
                                  color: theme.iconTheme.color),
                              onTap: () =>
                                  _toggleItemExpansion(metadata, itemId),
                            ),
                            if (isExpanded)
                              Container(
                                // Container para o conteúdo expandido
                                color: theme.colorScheme.surfaceVariant.withOpacity(
                                    0.1), // Um fundo sutil para a área expandida
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16.0, vertical: 12.0),
                                child: _isLoadingExpandedContent
                                    ? const Center(
                                        child: Padding(
                                        padding: EdgeInsets.all(8.0),
                                        child: SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2.5)),
                                      ))
                                    : (_loadedExpandedContent != null &&
                                            _loadedExpandedContent!.isNotEmpty
                                        ? MarkdownBody(
                                            data: _loadedExpandedContent!,
                                            selectable: true,
                                            styleSheet:
                                                MarkdownStyleSheet.fromTheme(
                                                        theme)
                                                    .copyWith(
                                              p: theme.textTheme.bodyMedium
                                                  ?.copyWith(
                                                      fontSize: 14,
                                                      height: 1.5,
                                                      color: theme.colorScheme
                                                          .onSurfaceVariant),
                                              strong: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: theme.colorScheme
                                                      .onSurfaceVariant),
                                              blockSpacing: 8.0,
                                            ),
                                          )
                                        : Text(
                                            "Conteúdo não disponível ou não pôde ser carregado.",
                                            style: TextStyle(
                                                color: theme.colorScheme
                                                    .onSurfaceVariant
                                                    .withOpacity(0.7)))),
                              ),
                            if (isExpanded && !_isLoadingExpandedContent)
                              Padding(
                                padding: const EdgeInsets.only(
                                    right: 8.0, top: 4.0, bottom: 8.0),
                                child: Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton.icon(
                                    icon: Icon(Icons.menu_book,
                                        size: 18,
                                        color: theme.colorScheme.primary),
                                    label: Text("Abrir na Bíblia",
                                        style: TextStyle(
                                            fontSize: 12,
                                            color: theme.colorScheme.primary,
                                            fontWeight: FontWeight.w500)),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      tapTargetSize:
                                          MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      final bookAbbrev =
                                          metadata['livro_curto'] as String?;
                                      final chapterStr =
                                          metadata['capitulo']?.toString();
                                      int? chapterInt;
                                      if (chapterStr != null)
                                        chapterInt = int.tryParse(chapterStr);

                                      if (bookAbbrev != null &&
                                          chapterInt != null) {
                                        StoreProvider.of<AppState>(context,
                                                listen: false)
                                            .dispatch(
                                                SetInitialBibleLocationAction(
                                                    bookAbbrev, chapterInt));
                                        StoreProvider.of<AppState>(context,
                                                listen: false)
                                            .dispatch(RequestBottomNavChangeAction(
                                                1)); // Assumindo que Bíblia é índice 1
                                        Navigator.popUntil(
                                            context,
                                            ModalRoute.withName(
                                                '/mainAppScreen'));
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Não foi possível abrir na Bíblia. Dados incompletos.')));
                                      }
                                    },
                                  ),
                                ),
                              ),
                            if (score != null && !isExpanded)
                              Padding(
                                padding: const EdgeInsets.only(
                                    left: 16.0, bottom: 8.0),
                                child: Text(
                                    "Similaridade: ${score.toStringAsFixed(3)}",
                                    style: TextStyle(
                                        fontSize: 10, color: Colors.grey[600])),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildFilterWidgets(
      BuildContext context, Map<String, dynamic> activeFilters) {
    final theme = Theme.of(context);
    List<String> testamentos = ["Antigo", "Novo"];

    List<DropdownMenuItem<String>> bookItems = [
      DropdownMenuItem<String>(
          value: null,
          child: Text("Todos Livros",
              style: TextStyle(fontSize: 12, color: theme.hintColor))),
    ];
    if (_localBooksMap.isNotEmpty) {
      List<MapEntry<String, dynamic>> sortedBooks = _localBooksMap.entries
          .toList()
        ..sort((a, b) =>
            (a.value['nome'] as String).compareTo(b.value['nome'] as String));
      for (var entry in sortedBooks) {
        bookItems.add(DropdownMenuItem<String>(
          value: entry.key,
          child: Text(entry.value['nome'] as String,
              style: TextStyle(
                  fontSize: 12, color: theme.textTheme.bodyLarge?.color)),
        ));
      }
    }

    List<DropdownMenuItem<String>> typeItems = [
      DropdownMenuItem<String>(
          value: null,
          child: Text("Todos Tipos",
              style: TextStyle(fontSize: 12, color: theme.hintColor))),
    ];
    for (var tipoMap in _tiposDeConteudoDisponiveis) {
      typeItems.add(DropdownMenuItem<String>(
        value: tipoMap['value'],
        child: Text(tipoMap['display']!,
            style: TextStyle(
                fontSize: 12, color: theme.textTheme.bodyLarge?.color)),
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: 8.0, vertical: 8.0), // Aumentado padding vertical
      decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.05),
          border: Border(
              bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.4), width: 0.5))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 120, // Ajustado
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text("Testamento",
                      style: TextStyle(
                          fontSize: 11, color: theme.hintColor)), // Reduzido
                  value: _selectedTestament,
                  items: [
                    DropdownMenuItem<String>(
                        value: null,
                        child: Text("Todos Test.",
                            style: TextStyle(
                                fontSize: 11, color: theme.hintColor))),
                    ...testamentos.map((String value) {
                      return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: theme.textTheme.bodyLarge
                                      ?.color))); // Reduzido
                    })
                  ],
                  onChanged: (String? newValue) {
                    setState(() => _selectedTestament = newValue);
                  },
                  style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 11), // Reduzido
                  dropdownColor: theme.dialogBackgroundColor,
                  iconEnabledColor: theme.iconTheme.color?.withOpacity(0.7),
                  itemHeight: 48, // Altura padrão
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 130, // Ajustado
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text("Livro",
                      style: TextStyle(
                          fontSize: 11, color: theme.hintColor)), // Reduzido
                  value: _selectedBookAbbrev,
                  items: bookItems
                      .map((item) => DropdownMenuItem(
                            value: item.value,
                            child: item.child != null
                                ? SizedBox(width: 90, child: item.child!)
                                : item.child,
                            alignment: item.alignment,
                          ))
                      .toList(), // Garante que o texto não quebre
                  onChanged: (String? newValue) {
                    setState(() => _selectedBookAbbrev = newValue);
                  },
                  style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 11), // Reduzido
                  dropdownColor: theme.dialogBackgroundColor,
                  iconEnabledColor: theme.iconTheme.color?.withOpacity(0.7),
                  itemHeight: 48,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 135, // Ajustado
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text("Tipo",
                      style: TextStyle(
                          fontSize: 11, color: theme.hintColor)), // Reduzido
                  value: _selectedType,
                  items: typeItems,
                  onChanged: (String? newValue) {
                    setState(() => _selectedType = newValue);
                  },
                  style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color,
                      fontSize: 11), // Reduzido
                  dropdownColor: theme.dialogBackgroundColor,
                  iconEnabledColor: theme.iconTheme.color?.withOpacity(0.7),
                  itemHeight: 48,
                ),
              ),
            ),
            const SizedBox(width: 8), // Reduzido
            ElevatedButton.icon(
              icon: Icon(Icons.filter_alt_outlined, size: 14), // Reduzido
              onPressed: () => _applyFiltersAndSearch(context),
              label: const Text("Filtrar",
                  style: TextStyle(fontSize: 11)), // Reduzido
              style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 8), // Reduzido
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.15),
                  foregroundColor: theme.colorScheme.primary,
                  elevation: 0,
                  side: BorderSide(
                      color: theme.colorScheme.primary.withOpacity(0.5),
                      width: 0.8)),
            ),
            const SizedBox(width: 2), // Reduzido
            IconButton(
              icon: Icon(Icons.clear_all_outlined,
                  size: 18,
                  color: theme.iconTheme.color?.withOpacity(0.6)), // Reduzido
              tooltip: "Limpar Filtros",
              onPressed: () => _clearAllFilters(context),
              padding: EdgeInsets.zero,
              constraints:
                  const BoxConstraints(minWidth: 36, minHeight: 36), // Ajustado
              splashRadius: 18,
            ),
          ],
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String get capitalizeFirstOfEach => split(" ")
      .map((str) =>
          str.isEmpty ? "" : '${str[0].toUpperCase()}${str.substring(1)}')
      .join(" ");
}
