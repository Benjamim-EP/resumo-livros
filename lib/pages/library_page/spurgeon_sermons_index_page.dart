// lib/pages/spurgeon_sermons_index_page.dart
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart'; // Para DateFormat
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/pages/biblie_page/utils.dart'; // Para os Dropdowns
import 'package:septima_biblia/pages/sermon_detail_page.dart';
import 'package:septima_biblia/redux/actions/sermon_search_actions.dart';
import 'package:septima_biblia/redux/reducers/sermon_search_reducer.dart'; // Para SermonSearchState
import 'package:septima_biblia/redux/store.dart'; // Para AppState
import 'package:unorm_dart/unorm_dart.dart' as unorm;

class PreloadSermonItem {
  final String title;
  final String generatedId;
  final String bookAbbrev;
  final String chapterNum;

  PreloadSermonItem({
    required this.title,
    required this.generatedId,
    required this.bookAbbrev,
    required this.chapterNum,
  });
}

class SpurgeonSermonsIndexPage extends StatefulWidget {
  const SpurgeonSermonsIndexPage({super.key});

  @override
  State<SpurgeonSermonsIndexPage> createState() =>
      _SpurgeonSermonsIndexPageState();
}

class _SpurgeonSermonsIndexPageState extends State<SpurgeonSermonsIndexPage> {
  List<PreloadSermonItem> _allPreloadedSermons = [];
  List<PreloadSermonItem> _displayedSermonsFromPreload = [];
  bool _isLoadingPreload = true;
  String? _errorPreload;
  Map<String, dynamic>? _bibleBooksMap;
  String? _selectedBookFilterLocal;
  int? _selectedChapterFilterLocal;
  final TextEditingController _localTitleSearchController =
      TextEditingController();
  String _localTitleSearchTerm = "";
  Timer? _localTitleSearchDebounce;
  final Random _random = Random();
  final int _preloadDisplayCount = 20;
  final ScrollController _preloadScrollController = ScrollController();
  bool _isLoadingMorePreload = false;

  final TextEditingController _semanticSermonSearchController =
      TextEditingController();
  bool _isSemanticSearchModeActive = false;

  String? _expandedSermonResultId;

  @override
  void initState() {
    super.initState();
    _loadInitialPreloadedData();
    _preloadScrollController.addListener(_scrollListenerForPreload);
    _localTitleSearchController.addListener(_onLocalTitleSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final store = StoreProvider.of<AppState>(context, listen: false);
        if (store.state.sermonSearchState.searchHistory.isEmpty &&
            !store.state.sermonSearchState.isLoadingHistory) {
          print(
              "SpurgeonSermonsIndexPage: Disparando LoadSermonSearchHistoryAction no initState.");
          store.dispatch(LoadSermonSearchHistoryAction());
        }
      }
    });
  }

  void _toggleSermonParagraphsExpansion(String sermonIdBase) {
    if (!mounted) return;
    setState(() {
      if (_expandedSermonResultId == sermonIdBase) {
        _expandedSermonResultId = null; // Recolhe se já estiver expandido
      } else {
        _expandedSermonResultId = sermonIdBase; // Expande o novo item
      }
    });
  }

  @override
  void dispose() {
    _preloadScrollController.removeListener(_scrollListenerForPreload);
    _preloadScrollController.dispose();
    _localTitleSearchController.removeListener(_onLocalTitleSearchChanged);
    _localTitleSearchController.dispose();
    _semanticSermonSearchController.dispose();
    _localTitleSearchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialPreloadedData() async {
    if (!mounted) return;
    setState(() => _isLoadingPreload = true);
    try {
      _bibleBooksMap = await BiblePageHelper.loadBooksMap();
      final String preloadJsonString = await rootBundle
          .loadString('assets/sermons/preloading_spurgeon_sermons.json');
      final Map<String, dynamic> preloadData = json.decode(preloadJsonString);
      final List<PreloadSermonItem> allSermonsFlatList = [];

      preloadData.forEach((bookAbbrev, chaptersMapOuter) {
        if (chaptersMapOuter is Map) {
          final chaptersMap = Map<String, dynamic>.from(chaptersMapOuter);
          chaptersMap.forEach((chapterNum, chapterDataOuter) {
            if (chapterDataOuter is Map) {
              final chapterData = Map<String, dynamic>.from(chapterDataOuter);
              final sermoesListRaw =
                  chapterData['sermoes'] as List<dynamic>? ?? [];
              for (var sermonEntry in sermoesListRaw) {
                if (sermonEntry is Map &&
                    sermonEntry['title'] != null &&
                    sermonEntry['id'] != null) {
                  allSermonsFlatList.add(PreloadSermonItem(
                    title: sermonEntry['title'] as String,
                    generatedId: sermonEntry['id'] as String,
                    bookAbbrev: bookAbbrev,
                    chapterNum: chapterNum,
                  ));
                }
              }
            }
          });
        }
      });

      if (mounted) {
        setState(() {
          _allPreloadedSermons = allSermonsFlatList;
          _applyLocalFiltersAndDisplayPreloadedSermons(isInitialLoad: true);
          _isLoadingPreload = false;
        });
      }
    } catch (e, s) {
      print("Erro ao carregar dados dos sermões (preload): $e\n$s");
      if (mounted) {
        setState(() {
          _errorPreload = "Falha ao carregar índice de sermões.";
          _isLoadingPreload = false;
        });
      }
    }
  }

  void _onLocalTitleSearchChanged() {
    if (_isSemanticSearchModeActive) return;
    if (_localTitleSearchDebounce?.isActive ?? false)
      _localTitleSearchDebounce!.cancel();
    _localTitleSearchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted &&
          _localTitleSearchController.text != _localTitleSearchTerm) {
        setState(() {
          _localTitleSearchTerm = _localTitleSearchController.text;
          _applyLocalFiltersAndDisplayPreloadedSermons();
        });
      } else if (mounted &&
          _localTitleSearchController.text.isEmpty &&
          _localTitleSearchTerm.isNotEmpty) {
        setState(() {
          _localTitleSearchTerm = "";
          _applyLocalFiltersAndDisplayPreloadedSermons();
        });
      }
    });
  }

  void _scrollListenerForPreload() {
    if (!_isSemanticSearchModeActive &&
        _preloadScrollController.position.pixels >=
            _preloadScrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMorePreload) {
      _loadMorePreloadedSermons();
    }
  }

  String _normalizeTextForSearchLocal(String text) {
    if (text.isEmpty) return "";
    return unorm
        .nfd(text)
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .toLowerCase();
  }

  bool _preloadedSermonMatchesTitleQuery(
      PreloadSermonItem sermon, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    final normalizedTitleToSearch = _normalizeTextForSearchLocal(sermon.title);
    final queryKeywords =
        normalizedQuery.split(' ').where((k) => k.isNotEmpty).toList();
    if (queryKeywords.isEmpty) return true;
    return queryKeywords
        .every((keyword) => normalizedTitleToSearch.contains(keyword));
  }

  List<PreloadSermonItem> _getPreloadedSermonListBasedOnLocalFilters() {
    List<PreloadSermonItem> filteredList = List.from(_allPreloadedSermons);
    final normalizedTitleQuery =
        _normalizeTextForSearchLocal(_localTitleSearchTerm);

    if (normalizedTitleQuery.isNotEmpty) {
      filteredList = filteredList
          .where((sermon) =>
              _preloadedSermonMatchesTitleQuery(sermon, normalizedTitleQuery))
          .toList();
    }
    if (_selectedBookFilterLocal != null) {
      filteredList = filteredList
          .where((sermon) => sermon.bookAbbrev == _selectedBookFilterLocal)
          .toList();
    }
    if (_selectedBookFilterLocal != null &&
        _selectedChapterFilterLocal != null) {
      filteredList = filteredList
          .where((sermon) =>
              sermon.chapterNum == _selectedChapterFilterLocal.toString())
          .toList();
    }
    return filteredList;
  }

  void _applyLocalFiltersAndDisplayPreloadedSermons(
      {bool isInitialLoad = false}) {
    if (!mounted) return;
    List<PreloadSermonItem> fullyFilteredList =
        _getPreloadedSermonListBasedOnLocalFilters();

    if (_localTitleSearchTerm.isEmpty &&
        _selectedBookFilterLocal == null &&
        _selectedChapterFilterLocal == null) {
      List<PreloadSermonItem> allSermonsCopy = List.from(_allPreloadedSermons);
      allSermonsCopy.shuffle(_random);
      setState(() => _displayedSermonsFromPreload =
          allSermonsCopy.take(_preloadDisplayCount).toList());
    } else {
      setState(() => _displayedSermonsFromPreload =
          fullyFilteredList.take(_preloadDisplayCount).toList());
    }

    if (_preloadScrollController.hasClients && !isInitialLoad) {
      _preloadScrollController.jumpTo(0.0);
    }
    if (isInitialLoad) {
      setState(() => _isLoadingPreload = false);
    }
  }

  void _loadMorePreloadedSermons() {
    if (!mounted || _allPreloadedSermons.isEmpty || _isLoadingMorePreload)
      return;
    List<PreloadSermonItem> sourceListForMore =
        _getPreloadedSermonListBasedOnLocalFilters();
    if (_displayedSermonsFromPreload.length >= sourceListForMore.length) return;

    setState(() => _isLoadingMorePreload = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        setState(() => _isLoadingMorePreload = false);
        return;
      }
      final currentCount = _displayedSermonsFromPreload.length;
      final List<PreloadSermonItem> nextBatch = sourceListForMore
          .skip(currentCount)
          .take(_preloadDisplayCount)
          .toList();
      setState(() {
        _displayedSermonsFromPreload.addAll(nextBatch);
        _isLoadingMorePreload = false;
      });
    });
  }

  void _navigateToSermonDetail(String sermonGeneratedId, String sermonTitle) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SermonDetailPage(
          sermonGeneratedId: sermonGeneratedId,
          sermonTitle: sermonTitle,
        ),
      ),
    );
  }

  void _performSemanticSermonSearch() {
    final query = _semanticSermonSearchController.text.trim();
    if (query.isNotEmpty) {
      StoreProvider.of<AppState>(context, listen: false).dispatch(
        SearchSermonsAction(query: query),
      );
    } else {
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(ClearSermonSearchResultsAction());
    }
  }

  void _toggleSemanticSearchMode() {
    setState(() {
      _isSemanticSearchModeActive = !_isSemanticSearchModeActive;
      if (!_isSemanticSearchModeActive) {
        _semanticSermonSearchController.clear();
        StoreProvider.of<AppState>(context, listen: false)
            .dispatch(ClearSermonSearchResultsAction());
        _applyLocalFiltersAndDisplayPreloadedSermons();
      } else {
        final store = StoreProvider.of<AppState>(context, listen: false);
        if (store.state.sermonSearchState.searchHistory.isEmpty &&
            !store.state.sermonSearchState.isLoadingHistory) {
          store.dispatch(LoadSermonSearchHistoryAction());
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isSemanticSearchModeActive
            ? "Busca Inteligente de Sermões"
            : "Sermões de C.H. Spurgeon"),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 8.0),
            child: Row(
              children: [
                IconButton(
                  icon: SvgPicture.asset(
                    'assets/icons/buscasemantica.svg',
                    colorFilter: ColorFilter.mode(
                        _isSemanticSearchModeActive
                            ? theme.colorScheme.primary
                            : (theme.iconTheme.color?.withOpacity(0.7) ??
                                theme.hintColor),
                        BlendMode.srcIn),
                    width: 24,
                    height: 24,
                  ),
                  tooltip: _isSemanticSearchModeActive
                      ? "Alternar para Lista/Filtros"
                      : "Alternar para Busca Inteligente",
                  onPressed: _toggleSemanticSearchMode,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _isSemanticSearchModeActive
                        ? _semanticSermonSearchController
                        : _localTitleSearchController,
                    style: TextStyle(
                        color: theme.textTheme.bodyLarge?.color,
                        fontSize: 14.5),
                    decoration: InputDecoration(
                      hintText: _isSemanticSearchModeActive
                          ? "Busca inteligente nos sermões..."
                          : "Buscar por título na lista...",
                      hintStyle: TextStyle(
                          color: theme.hintColor.withOpacity(0.8),
                          fontSize: 14),
                      suffixIcon: IconButton(
                        icon: Icon(Icons.search_rounded,
                            color: theme.iconTheme.color?.withOpacity(0.9),
                            size: 24),
                        tooltip: "Buscar",
                        onPressed: _isSemanticSearchModeActive
                            ? _performSemanticSermonSearch
                            : () =>
                                _applyLocalFiltersAndDisplayPreloadedSermons(),
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      filled: true,
                      fillColor: theme.inputDecorationTheme.fillColor ??
                          theme.cardColor.withOpacity(0.5),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: BorderSide.none),
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: BorderSide(
                              color: theme.dividerColor.withOpacity(0.3),
                              width: 0.8)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(25.0),
                          borderSide: BorderSide(
                              color: theme.colorScheme.primary, width: 1.5)),
                    ),
                    onSubmitted: (_) => _isSemanticSearchModeActive
                        ? _performSemanticSermonSearch()
                        : _applyLocalFiltersAndDisplayPreloadedSermons(),
                    textInputAction: TextInputAction.search,
                  ),
                ),
              ],
            ),
          ),
          if (!_isSemanticSearchModeActive) _buildFilterBarForPreload(theme),
          Expanded(
            child: StoreConnector<AppState, SermonSearchState>(
              converter: (store) => store.state.sermonSearchState,
              distinct: true, // Para evitar reconstruções desnecessárias
              builder: (context, sermonSearchState) {
                if (_isSemanticSearchModeActive) {
                  // 1. Se está carregando uma NOVA busca
                  if (sermonSearchState.isLoading &&
                      sermonSearchState.currentSermonQuery.isNotEmpty) {
                    print(
                        "SpurgeonSermonsIndexPage: Mostrando loader para nova busca de sermões (Query: '${sermonSearchState.currentSermonQuery}').");
                    return const Center(child: CircularProgressIndicator());
                  }
                  // 2. Se houve um erro na busca
                  if (!sermonSearchState.isLoading &&
                      sermonSearchState.error != null) {
                    print(
                        "SpurgeonSermonsIndexPage: Mostrando erro da busca de sermões: ${sermonSearchState.error}");
                    return Center(
                        child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                                "Erro na busca: ${sermonSearchState.error}",
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                    color: theme.colorScheme.error))));
                  }
                  // 3. Se houver resultados da busca ATUAL de sermões
                  if (sermonSearchState.sermonResults.isNotEmpty) {
                    print(
                        "SpurgeonSermonsIndexPage: Mostrando ${sermonSearchState.sermonResults.length} resultados da busca de sermões para '${sermonSearchState.currentSermonQuery}'.");
                    return _buildSemanticSearchResultsList(
                        theme, sermonSearchState.sermonResults);
                  }
                  // 4. Se NÃO há query ATIVA E HÁ histórico
                  if (sermonSearchState.currentSermonQuery.isEmpty &&
                      sermonSearchState.searchHistory.isNotEmpty) {
                    print(
                        "SpurgeonSermonsIndexPage: Mostrando histórico de ${sermonSearchState.searchHistory.length} buscas de sermões.");
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16.0, vertical: 12.0),
                          child: Text("Histórico de Buscas de Sermões:",
                              style: theme.textTheme.titleMedium?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.9))),
                        ),
                        Expanded(
                          child: ListView.builder(
                            itemCount: sermonSearchState.searchHistory.length,
                            itemBuilder: (context, index) {
                              final historyEntry =
                                  sermonSearchState.searchHistory[index];
                              final String query =
                                  historyEntry['query'] as String? ??
                                      'Busca inválida';
                              final String? timestampStr =
                                  historyEntry['timestamp'] as String?;
                              final DateTime? timestamp = timestampStr != null
                                  ? DateTime.tryParse(timestampStr)
                                  : null;

                              return ListTile(
                                leading: Icon(Icons.history,
                                    color: theme.iconTheme.color
                                        ?.withOpacity(0.6)),
                                title: Text(query,
                                    style: theme.textTheme.bodyLarge),
                                subtitle: timestamp != null
                                    ? Text(
                                        DateFormat('dd/MM/yy HH:mm')
                                            .format(timestamp.toLocal()),
                                        style: theme.textTheme.bodySmall)
                                    : null,
                                trailing: Icon(Icons.arrow_forward_ios_rounded,
                                    size: 16,
                                    color: theme.iconTheme.color
                                        ?.withOpacity(0.5)),
                                onTap: () {
                                  _semanticSermonSearchController.text = query;
                                  StoreProvider.of<AppState>(context,
                                          listen: false)
                                      .dispatch(
                                          ViewSermonSearchFromHistoryAction(
                                              historyEntry));
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  }
                  // 5. Se houve uma busca ATIVA mas não encontrou resultados
                  if (!sermonSearchState.isLoading &&
                      sermonSearchState.sermonResults.isEmpty &&
                      sermonSearchState.currentSermonQuery.isNotEmpty) {
                    print(
                        "SpurgeonSermonsIndexPage: Nenhum resultado para busca de sermões '${sermonSearchState.currentSermonQuery}'.");
                    return Center(
                        child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Text(
                                "Nenhum sermão encontrado para '${sermonSearchState.currentSermonQuery}'.",
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium)));
                  }
                  // 6. Mensagem padrão
                  print(
                      "SpurgeonSermonsIndexPage: Exibindo mensagem padrão/carregando histórico de sermões (isLoadingHistory: ${sermonSearchState.isLoadingHistory}).");
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        sermonSearchState.isLoadingHistory
                            ? "Carregando histórico de sermões..."
                            : "Digite algo para a busca inteligente de sermões. Seu histórico aparecerá aqui.",
                        style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.textTheme.bodySmall?.color
                                ?.withOpacity(0.7)),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                } else {
                  // Modo de lista pré-carregada
                  return _buildPreloadedSermonsList(theme);
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterBarForPreload(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 8.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
            bottom: BorderSide(
                color: theme.dividerColor.withOpacity(0.2), width: 1)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 2,
            child: UtilsBiblePage.buildBookDropdown(
              context: context,
              selectedBook: _selectedBookFilterLocal,
              booksMap: _bibleBooksMap,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedBookFilterLocal = newValue;
                  _selectedChapterFilterLocal = null;
                  _applyLocalFiltersAndDisplayPreloadedSermons();
                });
              },
              backgroundColor:
                  (theme.inputDecorationTheme.fillColor ?? theme.cardColor)
                      .withOpacity(0.4),
              textColor: theme.textTheme.bodySmall?.color,
              iconColor: theme.iconTheme.color?.withOpacity(0.6),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 1,
            child: UtilsBiblePage.buildChapterDropdown(
              context: context,
              selectedChapter: _selectedChapterFilterLocal,
              booksMap: _bibleBooksMap,
              selectedBook: _selectedBookFilterLocal,
              onChanged: (int? newValue) {
                setState(() {
                  _selectedChapterFilterLocal = newValue;
                  _applyLocalFiltersAndDisplayPreloadedSermons();
                });
              },
              backgroundColor:
                  (theme.inputDecorationTheme.fillColor ?? theme.cardColor)
                      .withOpacity(0.4),
              textColor: theme.textTheme.bodySmall?.color,
              iconColor: theme.iconTheme.color?.withOpacity(0.6),
            ),
          ),
          IconButton(
            icon: Icon(Icons.filter_list_off_outlined,
                color: theme.iconTheme.color?.withOpacity(0.6), size: 22),
            tooltip: "Limpar Filtros Livro/Cap.",
            onPressed: () {
              _localTitleSearchController.clear();
              setState(() {
                _localTitleSearchTerm = "";
                _selectedBookFilterLocal = null;
                _selectedChapterFilterLocal = null;
                _applyLocalFiltersAndDisplayPreloadedSermons();
              });
            },
            splashRadius: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildPreloadedSermonsList(ThemeData theme) {
    if (_isLoadingPreload) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorPreload != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_errorPreload!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
              textAlign: TextAlign.center),
        ),
      );
    }
    if (_displayedSermonsFromPreload.isEmpty) {
      String message = "Nenhum sermão para exibir.";
      if (_localTitleSearchTerm.isNotEmpty ||
          _selectedBookFilterLocal != null ||
          _selectedChapterFilterLocal != null) {
        message = "Nenhum sermão encontrado para os filtros aplicados.";
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(message,
              style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
              textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.builder(
      controller: _preloadScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      itemCount:
          _displayedSermonsFromPreload.length + (_isLoadingMorePreload ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _displayedSermonsFromPreload.length) {
          return _isLoadingMorePreload
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()))
              : const SizedBox.shrink();
        }
        final sermonItem = _displayedSermonsFromPreload[index];
        final String title = sermonItem.title;
        final String generatedId = sermonItem.generatedId;
        final String bookName = _bibleBooksMap?[sermonItem.bookAbbrev]
                ?['nome'] ??
            sermonItem.bookAbbrev.toUpperCase();
        final String referenceHint = "$bookName ${sermonItem.chapterNum}";

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 5.0, horizontal: 4.0),
          elevation: 1.5,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          color: theme.cardColor.withOpacity(0.85),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            title: Text(title,
                style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: 15,
                    color: theme.textTheme.bodyLarge?.color)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text("Indexado em: $referenceHint",
                  style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                      fontSize: 11.5)),
            ),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 14, color: theme.iconTheme.color?.withOpacity(0.6)),
            onTap: () => _navigateToSermonDetail(generatedId, title),
          ),
        );
      },
    );
  }

  Widget _buildSemanticSearchResultsList(
      ThemeData theme, List<Map<String, dynamic>> sermonResults) {
    if (sermonResults.isEmpty) {
      // Adiciona uma verificação para lista vazia, embora a lógica externa já deva cobrir
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            "Nenhum sermão encontrado para os critérios.",
            style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: sermonResults.length,
      itemBuilder: (context, index) {
        final sermonData = sermonResults[index];
        final String sermonIdBase =
            sermonData['sermon_id_base'] as String? ?? 'sermon_result_$index';
        final String title =
            sermonData['title_translated'] as String? ?? 'Sermão Sem Título';
        final String scripture =
            sermonData['main_scripture_abbreviated'] as String? ?? 'N/A';
        final String preacher =
            sermonData['preacher'] as String? ?? 'C.H. Spurgeon';

        final List<dynamic> relevantParagraphsRaw =
            sermonData['relevant_paragraphs'] as List<dynamic>? ?? [];
        final List<String> relevantParagraphsTexts = relevantParagraphsRaw
            .map((p) => (p is Map && p['text_preview'] is String)
                ? p['text_preview'] as String
                : null)
            .where((p) => p != null)
            .cast<String>()
            .toList();

        final bool isExpanded = _expandedSermonResultId == sermonIdBase;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
          elevation: 2.5,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          color: theme.cardColor,
          child: Padding(
            padding: const EdgeInsets.all(14.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Título do Sermão
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),

                // >>> INÍCIO DA MODIFICAÇÃO: Mostrar Pregador E Preview dos Parágrafos <<<
                Text(
                  // Pregador
                  "Por: $preacher",
                  style: theme.textTheme.bodySmall?.copyWith(
                      // Usando bodySmall para menos destaque que o preview
                      fontStyle: FontStyle.italic,
                      fontSize: 11.5, // Um pouco menor
                      color:
                          theme.textTheme.bodySmall?.color?.withOpacity(0.75)),
                ),

                if (scripture.isNotEmpty && scripture != 'N/A') ...[
                  const SizedBox(height: 4),
                  Text(
                    // Passagem Principal
                    "Passagem Principal: $scripture",
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 11.5, // Consistente com o pregador
                        color: theme.colorScheme.secondary.withOpacity(0.9)),
                  ),
                ],

                // Preview dos Trechos Relevantes (mesmo quando não expandido)
                if (relevantParagraphsTexts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    // Pega o primeiro parágrafo relevante para o preview
                    '"${relevantParagraphsTexts.first.length > 150 ? relevantParagraphsTexts.first.substring(0, 150) + "..." : relevantParagraphsTexts.first}"',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      height: 1.4,
                      fontSize: 13, // Tamanho para o preview
                      color: theme.colorScheme.onSurface.withOpacity(0.75),
                      fontStyle: FontStyle.italic,
                    ),
                    maxLines: 3, // Limita o preview a 3 linhas
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                // >>> FIM DA MODIFICAÇÃO <<<

                const SizedBox(height: 10), // Espaço antes dos botões

                // Botão para expandir/recolher parágrafos relevantes
                if (relevantParagraphsTexts.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: Icon(
                        isExpanded
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        size: 18,
                        color: theme.colorScheme.secondary,
                      ),
                      label: Text(
                        isExpanded
                            ? "Ocultar Parágrafos"
                            : "Ver Todos os Parágrafos (${relevantParagraphsTexts.length})",
                        style: TextStyle(
                            fontSize: 12,
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w500),
                      ),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () =>
                          _toggleSermonParagraphsExpansion(sermonIdBase),
                    ),
                  ),

                // Exibição dos parágrafos expandidos (quando isExpanded é true)
                if (isExpanded && relevantParagraphsTexts.isNotEmpty)
                  AnimatedSize(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                    child: Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                      padding: const EdgeInsets.all(12.0),
                      decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceVariant
                              .withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8.0),
                          border: Border.all(
                              color: theme.dividerColor.withOpacity(0.3),
                              width: 0.8)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: relevantParagraphsTexts
                            .asMap()
                            .entries
                            .map((entry) {
                          int pIndex = entry.key;
                          String paragraphText = entry.value;
                          return Padding(
                            padding: EdgeInsets.only(
                                bottom:
                                    pIndex < relevantParagraphsTexts.length - 1
                                        ? 12.0
                                        : 0.0),
                            child: SelectableText(
                              paragraphText,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                height: 1.55,
                                color: theme.colorScheme.onSurfaceVariant
                                    .withOpacity(0.9),
                              ),
                              textAlign: TextAlign.justify,
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                if (relevantParagraphsTexts.isEmpty && isExpanded)
                  Padding(
                    // Mensagem se tentou expandir mas não há trechos (caso raro)
                    padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                    child: Text(
                      "Nenhum trecho relevante destacado para este sermão.",
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontStyle: FontStyle.italic,
                          color: theme.colorScheme.onSurfaceVariant
                              .withOpacity(0.6)),
                    ),
                  ),

                // Espaçamento antes do botão "Ler Sermão Completo"
                const SizedBox(height: 8),

                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.read_more_outlined, size: 16),
                    label: const Text("Ler Sermão Completo"),
                    style: ElevatedButton.styleFrom(
                        backgroundColor:
                            theme.colorScheme.primary.withOpacity(0.85),
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        textStyle: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w500)),
                    onPressed: () {
                      _navigateToSermonDetail(sermonIdBase, title);
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
