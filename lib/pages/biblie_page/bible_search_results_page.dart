// lib/pages/biblie_page/bible_search_results_page.dart
import 'dart:convert'; // Para json.decode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Para rootBundle
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/redux/actions/bible_search_actions.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/services/firestore_service.dart';
import 'package:septima_biblia/pages/biblie_page/bible_search_filter_bar.dart'; // IMPORTADO

class BibleSearchResultsPage extends StatefulWidget {
  final String initialQuery;
  const BibleSearchResultsPage({super.key, required this.initialQuery});

  @override
  State<BibleSearchResultsPage> createState() => _BibleSearchResultsPageState();
}

class _BibleSearchResultsPageState extends State<BibleSearchResultsPage> {
  late TextEditingController _queryController;
  Map<String, dynamic> _localBooksMap = {};

  String? _expandedItemId;
  String? _loadedExpandedContent;
  bool _isLoadingExpandedContent = false;

  final FirestoreService _firestoreService = FirestoreService();

  @override
  void initState() {
    super.initState();
    _queryController = TextEditingController(text: widget.initialQuery);
    _loadBooksMapForFilterBar();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final store = StoreProvider.of<AppState>(context, listen: false);
        if (widget.initialQuery.isNotEmpty &&
            store.state.bibleSearchState.results.isEmpty) {
          _triggerSearchWithCurrentFilters(context, widget.initialQuery);
        }
      }
    });
  }

  Future<void> _loadBooksMapForFilterBar() async {
    final map = await BiblePageHelper.loadBooksMap();
    if (mounted) {
      setState(() {
        _localBooksMap = map;
      });
    }
  }

  void _triggerSearchWithCurrentFilters(BuildContext context, String query) {
    final store = StoreProvider.of<AppState>(context, listen: false);
    final queryToSearch = query.trim(); // Usa a query passada ou do controller

    if (queryToSearch.isNotEmpty) {
      store.dispatch(SearchBibleSemanticAction(queryToSearch));
    } else if (store.state.bibleSearchState.currentQuery.isNotEmpty) {
      store.dispatch(
          SearchBibleSemanticAction(store.state.bibleSearchState.currentQuery));
    } else {
      print("BibleSearchResultsPage: Nenhuma query para buscar.");
      store.dispatch(SearchBibleSemanticSuccessAction([]));
    }
  }

  void _handleFilterChangeAndUpdateSearch({
    String? testament,
    String? bookAbbrev,
    String? contentType,
  }) {
    final store = StoreProvider.of<AppState>(context, listen: false);
    store.dispatch(SetBibleSearchFilterAction('testamento', testament));
    store.dispatch(SetBibleSearchFilterAction('livro_curto', bookAbbrev));
    store.dispatch(SetBibleSearchFilterAction('tipo', contentType));
    _triggerSearchWithCurrentFilters(context, _queryController.text);
  }

  void _handleClearFiltersAndSearch() {
    final store = StoreProvider.of<AppState>(context, listen: false);
    store.dispatch(ClearBibleSearchFiltersAction());
    _triggerSearchWithCurrentFilters(context, _queryController.text);
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
          'nvi',
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
        if (_isLoadingExpandedContent && _expandedItemId == null) {
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
              _triggerSearchWithCurrentFilters(context, query);
            }),
        actions: [
          IconButton(
            icon: Icon(Icons.search,
                color: theme.appBarTheme.actionsIconTheme?.color ??
                    theme.colorScheme.onPrimary),
            onPressed: () {
              _triggerSearchWithCurrentFilters(context, _queryController.text);
            },
          )
        ],
      ),
      body: StoreConnector<AppState, BibleSearchState>(
        converter: (store) => store.state.bibleSearchState,
        builder: (context, state) {
          return Column(
            children: [
              BibleSearchFilterBar(
                initialBooksMap: _localBooksMap,
                initialActiveFilters: state.activeFilters,
                onFilterChanged: (
                    {String? testament,
                    String? bookAbbrev,
                    String? contentType}) {
                  _handleFilterChangeAndUpdateSearch(
                    testament: testament,
                    bookAbbrev: bookAbbrev,
                    contentType: contentType,
                  );
                },
                onClearFilters: () {
                  _handleClearFiltersAndSearch();
                },
              ),
              if (state.isLoading && state.results.isEmpty)
                const Expanded(
                    child: Center(child: CircularProgressIndicator())),
              if (!state.isLoading && state.error != null)
                Expanded(
                    child: Center(
                        child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text("Erro na busca: ${state.error}",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.error)),
                ))),
              if (!state.isLoading &&
                  state.error == null &&
                  state.results.isEmpty &&
                  state.currentQuery.isNotEmpty)
                Expanded(
                    child: Center(
                        child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                      "Nenhum resultado encontrado para '${state.currentQuery}' com os filtros aplicados.",
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium),
                ))),
              if (!state.isLoading &&
                  state.error == null &&
                  state.results.isEmpty &&
                  state.currentQuery.isEmpty)
                Expanded(
                    child: Center(
                        child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                      "Use a busca e os filtros acima para encontrar referências bíblicas.",
                      textAlign: TextAlign.center,
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
                        previewContent = commentaryTitle ?? "Ver comentário...";
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
                              AnimatedSize(
                                // Para uma animação suave ao expandir/recolher
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                                child: Container(
                                  width: double
                                      .infinity, // Garante que o container ocupe a largura
                                  color: theme.colorScheme.surfaceVariant
                                      .withOpacity(0.1),
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
                                            .dispatch(
                                                RequestBottomNavChangeAction(
                                                    1));
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
                                    left: 16.0,
                                    bottom: 8.0,
                                    top: 0), // Ajustado padding
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
}

extension StringExtension on String {
  String get capitalizeFirstOfEach => split(" ")
      .map((str) =>
          str.isEmpty ? "" : '${str[0].toUpperCase()}${str.substring(1)}')
      .join(" ");
}
