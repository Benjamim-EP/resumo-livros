// lib/pages/bible_search_results_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:resumo_dos_deuses_flutter/redux/reducers.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/bible_search_actions.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions.dart'; // Ações gerais como SetInitialBibleLocationAction

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

  final List<String> _tiposDisponiveis = [
    "biblia_comentario_secao", // Exemplo de tipo de metadado do Pinecone
    "versiculo_biblico_unico", // Exemplo
    "capitulo_completo" // Exemplo
    // Adicione outros tipos que você tem no seu metadado 'tipo' do Pinecone
  ];

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _loadBooksMapForDropdown();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final initialFilters =
            StoreProvider.of<AppState>(context, listen: false)
                .state
                .bibleSearchState
                .activeFilters;
        setState(() {
          _selectedTestament = initialFilters['testamento'] as String?;
          _selectedBookAbbrev = initialFilters['livro_curto'] as String?;
          _selectedType = initialFilters['tipo'] as String?;
        });
        // Realiza a busca inicial se a query não estiver vazia
        // Isso é importante se a navegação para esta página não disparou a busca antes.
        // Mas no fluxo atual, a busca é disparada antes de navegar.
        // if (widget.initialQuery.isNotEmpty && StoreProvider.of<AppState>(context, listen: false).state.bibleSearchState.results.isEmpty) {
        //   _applyFiltersAndSearch(context);
        // }
      }
    });
  }

  Future<void> _loadBooksMapForDropdown() async {
    final map = await BiblePageHelper.loadBooksMap();
    if (mounted) {
      setState(() {
        _localBooksMap = map;
      });
    }
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
      // Se ambas as queries estiverem vazias, talvez mostrar uma mensagem ou não buscar.
      // Por ora, não buscar se não houver query.
      print("Nenhuma query para buscar após aplicar filtros.");
      // Opcionalmente, limpar resultados se não houver query:
      // store.dispatch(SearchBibleSemanticSuccessAction([]));
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
      // Opcionalmente, limpar resultados:
      // store.dispatch(SearchBibleSemanticSuccessAction([]));
    }
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
            controller: _queryController,
            decoration: InputDecoration(
                hintText: 'Buscar na Bíblia...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: theme.hintColor.withOpacity(0.7))),
            style: TextStyle(
                color: theme.textTheme.bodyLarge?.color ??
                    theme.colorScheme.onSurface),
            onSubmitted: (query) {
              if (query.trim().isNotEmpty) {
                _applyFiltersAndSearch(context);
              }
            }),
        actions: [
          IconButton(
            icon: Icon(Icons.search,
                color: theme.appBarTheme.actionsIconTheme?.color),
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
              if (state.isLoading)
                const Expanded(
                    child: Center(child: CircularProgressIndicator())),
              if (state.error != null && !state.isLoading)
                Expanded(
                    child: Center(
                        child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Erro: ${state.error}',
                    style: TextStyle(color: theme.colorScheme.error),
                    textAlign: TextAlign.center,
                  ),
                ))),
              if (!state.isLoading &&
                  state.error == null &&
                  state.results.isEmpty &&
                  state.currentQuery.isNotEmpty)
                const Expanded(
                    child: Center(
                        child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Nenhum resultado encontrado para sua busca.',
                      textAlign: TextAlign.center),
                ))),
              if (!state.isLoading &&
                  state.error == null &&
                  state.results.isEmpty &&
                  state.currentQuery.isEmpty)
                const Expanded(
                    child: Center(
                        child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('Digite algo para buscar ou refine seus filtros.',
                      textAlign: TextAlign.center),
                ))),
              if (!state.isLoading &&
                  state.error == null &&
                  state.results.isNotEmpty)
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.all(8.0),
                    itemCount: state.results.length,
                    itemBuilder: (context, index) {
                      final item = state.results[index];

                      Map<String, dynamic> metadata = {};
                      final rawMetadata = item['metadata'];
                      if (rawMetadata is Map) {
                        metadata = Map<String, dynamic>.from(rawMetadata.map(
                            (key, value) => MapEntry(key.toString(), value)));
                      }

                      final content = metadata['content'] as String? ??
                          'Conteúdo não disponível.';
                      final reference =
                          "${metadata['livro_completo'] ?? metadata['livro_curto'] ?? 'Livro Desconhecido'} ${metadata['capitulo'] ?? '?'}:${metadata['versiculos'] ?? '?'}";
                      final commentaryTitle =
                          metadata['titulo_comentario'] as String?;
                      final score = item['score'] as double?;

                      return Card(
                        elevation: 2,
                        margin: const EdgeInsets.symmetric(vertical: 6.0),
                        child: ListTile(
                          title: Text(reference,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (commentaryTitle != null &&
                                  commentaryTitle.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(
                                      top: 4.0, bottom: 4.0),
                                  child: Text("Comentário: $commentaryTitle",
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontStyle: FontStyle.italic)),
                                ),
                              Container(
                                // Usar Container para controlar melhor a altura e evitar overflow do Markdown
                                constraints: const BoxConstraints(
                                    maxHeight:
                                        70), // Altura máxima para o snippet
                                child: SingleChildScrollView(
                                  // Permite scroll se o conteúdo for maior
                                  child: MarkdownBody(
                                    data: content,
                                    styleSheet: MarkdownStyleSheet.fromTheme(
                                            Theme.of(context))
                                        .copyWith(
                                      p: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(
                                              fontSize:
                                                  12.5), // Não precisa de overflow aqui
                                    ),
                                  ),
                                ),
                              ),
                              if (score != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4.0),
                                  child: Text(
                                      "Similaridade: ${score.toStringAsFixed(4)}",
                                      style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey[600])),
                                ),
                            ],
                          ),
                          isThreeLine: true,
                          onTap: () {
                            final bookAbbrev =
                                metadata['livro_curto'] as String?;
                            final chapterStr = metadata['capitulo']?.toString();
                            int? chapterInt;
                            if (chapterStr != null) {
                              chapterInt = int.tryParse(chapterStr);
                            }

                            if (bookAbbrev != null && chapterInt != null) {
                              StoreProvider.of<AppState>(context, listen: false)
                                  .dispatch(SetInitialBibleLocationAction(
                                      bookAbbrev, chapterInt));
                              StoreProvider.of<AppState>(context, listen: false)
                                  .dispatch(RequestBottomNavChangeAction(
                                      2)); // 2 é o índice da Bíblia
                              Navigator.popUntil(context,
                                  ModalRoute.withName('/mainAppScreen'));
                            } else {
                              print(
                                  "Erro: metadados insuficientes para navegação - Livro: $bookAbbrev, Capítulo: $chapterStr");
                              ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                      content: Text(
                                          'Não foi possível navegar para esta referência.')));
                            }
                          },
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
          value: entry.key, // A abreviação (livro_curto)
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
    for (var tipo in _tiposDisponiveis) {
      typeItems.add(DropdownMenuItem<String>(
        value: tipo,
        child: Text(tipo.replaceAll("_", " ").capitalizeFirstOfEach,
            style: TextStyle(
                fontSize: 12, color: theme.textTheme.bodyLarge?.color)),
      ));
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
      decoration: BoxDecoration(
          color: theme.cardColor.withOpacity(0.05),
          border: Border(
              bottom: BorderSide(color: theme.dividerColor, width: 0.5))),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: <Widget>[
            SizedBox(
              width: 125,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text("Testamento",
                      style: TextStyle(fontSize: 12, color: theme.hintColor)),
                  value: _selectedTestament,
                  items: [
                    DropdownMenuItem<String>(
                        value: null,
                        child: Text("Todos Test.",
                            style: TextStyle(
                                fontSize: 12, color: theme.hintColor))),
                    ...testamentos.map((String value) {
                      return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value,
                              style: TextStyle(
                                  fontSize: 12,
                                  color: theme.textTheme.bodyLarge?.color)));
                    })
                  ],
                  onChanged: (String? newValue) =>
                      setState(() => _selectedTestament = newValue),
                  style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color, fontSize: 12),
                  dropdownColor: theme.dialogBackgroundColor,
                  iconEnabledColor: theme.iconTheme.color,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 140,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text("Livro",
                      style: TextStyle(fontSize: 12, color: theme.hintColor)),
                  value: _selectedBookAbbrev,
                  items: bookItems,
                  onChanged: (String? newValue) =>
                      setState(() => _selectedBookAbbrev = newValue),
                  style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color, fontSize: 12),
                  dropdownColor: theme.dialogBackgroundColor,
                  iconEnabledColor: theme.iconTheme.color,
                ),
              ),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 135,
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  isExpanded: true,
                  hint: Text("Tipo",
                      style: TextStyle(fontSize: 12, color: theme.hintColor)),
                  value: _selectedType,
                  items: typeItems,
                  onChanged: (String? newValue) =>
                      setState(() => _selectedType = newValue),
                  style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color, fontSize: 12),
                  dropdownColor: theme.dialogBackgroundColor,
                  iconEnabledColor: theme.iconTheme.color,
                ),
              ),
            ),
            const SizedBox(width: 10),
            ElevatedButton.icon(
              icon: const Icon(Icons.filter_list, size: 16),
              onPressed: () => _applyFiltersAndSearch(context),
              label: const Text("Filtrar", style: TextStyle(fontSize: 12)),
              style: ElevatedButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.clear_all, size: 20),
              tooltip: "Limpar Filtros",
              onPressed: () => _clearAllFilters(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}

// Helper extension para capitalizar a primeira letra de cada palavra
extension StringExtension on String {
  String get capitalizeFirstOfEach => split(" ")
      .map((str) =>
          str.isEmpty ? "" : '${str[0].toUpperCase()}${str.substring(1)}')
      .join(" ");
}
