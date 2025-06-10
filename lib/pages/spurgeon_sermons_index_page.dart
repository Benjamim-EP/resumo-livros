// lib/pages/spurgeon_sermons_index_page.dart
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';
import 'package:resumo_dos_deuses_flutter/pages/sermon_detail_page.dart';
import 'package:resumo_dos_deuses_flutter/redux/actions/sermon_search_actions.dart';
import 'package:resumo_dos_deuses_flutter/redux/reducers/sermon_search_reducer.dart';
import 'package:resumo_dos_deuses_flutter/redux/store.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

class PreloadSermonItem {
  final String title;
  final String generatedId; // Este é o ID base do sermão (ex: sermon_1000)
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
  // Estados para a lista pré-carregada e filtros locais
  List<PreloadSermonItem> _allPreloadedSermons = [];
  List<PreloadSermonItem> _displayedSermonsFromPreload = [];
  bool _isLoadingPreload = true;
  String? _errorPreload;
  Map<String, dynamic>?
      _bibleBooksMap; // Para nomes de livros nos filtros locais
  String? _selectedBookFilterLocal; // Filtro de livro para lista pré-carregada
  int?
      _selectedChapterFilterLocal; // Filtro de capítulo para lista pré-carregada
  final TextEditingController _localTitleSearchController =
      TextEditingController(); // Para busca local por título
  String _localTitleSearchTerm = "";
  Timer? _localTitleSearchDebounce;
  final Random _random = Random();
  final int _preloadDisplayCount = 20;
  final ScrollController _preloadScrollController = ScrollController();
  bool _isLoadingMorePreload = false;

  // Estado para a busca semântica
  final TextEditingController _semanticSermonSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadInitialPreloadedData();
    _preloadScrollController.addListener(_scrollListenerForPreload);
    _localTitleSearchController.addListener(_onLocalTitleSearchChanged);
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

  // --- MÉTODOS PARA A LISTA PRÉ-CARREGADA E FILTROS LOCAIS ---
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
    if (_preloadScrollController.position.pixels >=
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
      filteredList = filteredList.where((sermon) {
        return _preloadedSermonMatchesTitleQuery(sermon, normalizedTitleQuery);
      }).toList();
    }
    if (_selectedBookFilterLocal != null) {
      filteredList = filteredList.where((sermon) {
        return sermon.bookAbbrev == _selectedBookFilterLocal;
      }).toList();
    }
    if (_selectedBookFilterLocal != null &&
        _selectedChapterFilterLocal != null) {
      filteredList = filteredList.where((sermon) {
        return sermon.chapterNum == _selectedChapterFilterLocal.toString();
      }).toList();
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
      // Se nenhum filtro local está ativo, mostra aleatoriamente
      List<PreloadSermonItem> allSermonsCopy = List.from(_allPreloadedSermons);
      allSermonsCopy.shuffle(_random);
      setState(() => _displayedSermonsFromPreload =
          allSermonsCopy.take(_preloadDisplayCount).toList());
    } else {
      setState(() => _displayedSermonsFromPreload =
          fullyFilteredList.take(_preloadDisplayCount).toList());
    }

    if (_preloadScrollController.hasClients && !isInitialLoad)
      _preloadScrollController.jumpTo(0.0);
    if (isInitialLoad) setState(() => _isLoadingPreload = false);
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

  // --- MÉTODOS PARA BUSCA SEMÂNTICA ---
  void _performSemanticSermonSearch() {
    final query = _semanticSermonSearchController.text.trim();
    if (query.isNotEmpty) {
      _localTitleSearchController.clear(); // Limpa a busca local
      setState(() {
        _localTitleSearchTerm = "";
        _selectedBookFilterLocal = null;
        _selectedChapterFilterLocal = null;
      });
      StoreProvider.of<AppState>(context, listen: false).dispatch(
        SearchSermonsAction(query: query), // Usa os topK padrão da action
      );
    } else {
      // Se a query semântica estiver vazia, limpa os resultados semânticos
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(ClearSermonSearchResultsAction());
      // E reaplica os filtros locais para mostrar a lista pré-carregada
      _applyLocalFiltersAndDisplayPreloadedSermons();
    }
  }

  // --- WIDGETS DE CONSTRUÇÃO ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sermões de C.H. Spurgeon"),
        backgroundColor: theme.appBarTheme.backgroundColor,
        foregroundColor: theme.appBarTheme.foregroundColor,
      ),
      body: Column(
        children: [
          // Barra de Busca Semântica
          Padding(
            padding: const EdgeInsets.fromLTRB(12.0, 12.0, 12.0, 8.0),
            child: TextField(
              controller: _semanticSermonSearchController,
              style: TextStyle(
                  color: theme.textTheme.bodyLarge?.color, fontSize: 14.5),
              decoration: InputDecoration(
                hintText: "Busca inteligente por sermões...",
                hintStyle: TextStyle(
                    color: theme.hintColor.withOpacity(0.8), fontSize: 14),
                prefixIcon: Padding(
                  // Adiciona padding ao redor do SVG
                  padding: const EdgeInsets.all(10.0),
                  child: SvgPicture.asset(
                    'assets/icons/buscasemantica.svg',
                    colorFilter: ColorFilter.mode(
                        theme.iconTheme.color?.withOpacity(0.7) ??
                            theme.hintColor,
                        BlendMode.srcIn),
                    width: 18,
                    height: 18,
                  ),
                ),
                suffixIcon: IconButton(
                  icon: Icon(Icons.search_rounded,
                      color: theme.iconTheme.color?.withOpacity(0.9), size: 24),
                  tooltip: "Buscar Sermões",
                  onPressed: _performSemanticSermonSearch,
                ),
                isDense: true,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor ??
                    theme.cardColor.withOpacity(0.5),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide: BorderSide(
                      color: theme.dividerColor.withOpacity(0.3), width: 0.8),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(25.0),
                  borderSide:
                      BorderSide(color: theme.colorScheme.primary, width: 1.5),
                ),
              ),
              onSubmitted: (_) => _performSemanticSermonSearch(),
              textInputAction: TextInputAction.search,
            ),
          ),

          // Barra de Filtros para a lista pré-carregada (opcional)
          // Se você decidir mostrar sempre, descomente a linha abaixo.
          // Caso contrário, ela só será relevante se não houver busca semântica ativa.
          // _buildFilterBarForPreloaded(theme),

          Expanded(
            child: StoreConnector<AppState, SermonSearchState>(
              converter: (store) => store.state.sermonSearchState,
              builder: (context, sermonSearchState) {
                if (sermonSearchState.isLoading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (sermonSearchState.error != null) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text("Erro na busca: ${sermonSearchState.error}",
                          style: TextStyle(color: theme.colorScheme.error)),
                    ),
                  );
                }

                // Prioriza resultados da busca semântica se houver uma query ativa para ela
                if (sermonSearchState.currentSermonQuery.isNotEmpty) {
                  if (sermonSearchState.sermonResults.isNotEmpty) {
                    return _buildSemanticSearchResultsList(
                        theme, sermonSearchState.sermonResults);
                  } else {
                    // Query semântica foi feita, mas não retornou nada
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text("Nenhum sermão encontrado para sua busca.",
                            style: theme.textTheme.bodyMedium),
                      ),
                    );
                  }
                }

                // Fallback: Mostrar a lista pré-carregada/filtrada por título local
                return _buildPreloadedSermonsList(theme);
              },
            ),
          ),
        ],
      ),
    );
  }

  // Barra de filtro para a lista pré-carregada (se decidir mantê-la visível)
  Widget _buildFilterBarForPreload(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor, // Ou uma cor de destaque sutil
        border: Border(
            bottom: BorderSide(
                color: theme.dividerColor.withOpacity(0.2), width: 1)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _localTitleSearchController,
            style: TextStyle(
                color: theme.textTheme.bodyLarge?.color, fontSize: 13),
            decoration: InputDecoration(
              hintText: "Filtrar por título (lista atual)...",
              hintStyle: TextStyle(
                  color: theme.hintColor.withOpacity(0.7), fontSize: 13),
              prefixIcon: Icon(Icons.title,
                  color: theme.iconTheme.color?.withOpacity(0.6), size: 18),
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              filled: true,
              fillColor:
                  (theme.inputDecorationTheme.fillColor ?? theme.cardColor)
                      .withOpacity(0.4),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.0),
                  borderSide: BorderSide.none),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: UtilsBiblePage.buildBookDropdown(
                  context: context,
                  selectedBook: _selectedBookFilterLocal,
                  booksMap: _bibleBooksMap,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedBookFilterLocal = newValue;
                      _selectedChapterFilterLocal =
                          null; // Reseta capítulo ao mudar livro
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
                flex: 2,
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
                    color: theme.iconTheme.color?.withOpacity(0.6), size: 20),
                tooltip: "Limpar Filtros Locais",
                onPressed: () {
                  _localTitleSearchController
                      .clear(); // Limpa o texto da busca local
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
      String message = "Nenhum sermão para exibir no momento.";
      if (_localTitleSearchTerm.isNotEmpty ||
          _selectedBookFilterLocal != null ||
          _selectedChapterFilterLocal != null) {
        message = "Nenhum sermão encontrado para os filtros locais aplicados.";
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
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w500, fontSize: 15)),
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
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: sermonResults.length,
      itemBuilder: (context, index) {
        final sermonData = sermonResults[index];
        final String sermonIdBase =
            sermonData['sermon_id_base'] ?? 'unknown_id';
        final String title =
            sermonData['title_translated'] ?? 'Sermão Sem Título';
        final String scripture =
            sermonData['main_scripture_abbreviated'] ?? 'N/A';
        final String preacher = sermonData['preacher'] ?? 'C.H. Spurgeon';
        final List<dynamic> relevantParagraphs =
            sermonData['relevant_paragraphs'] ?? [];
        // final double relevanceScore = (sermonData['relevance_score'] as num?)?.toDouble() ?? 0.0;

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
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 5),
                Text(
                  "Por: $preacher",
                  style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      fontSize: 12.5,
                      color:
                          theme.textTheme.bodySmall?.color?.withOpacity(0.9)),
                ),
                if (scripture.isNotEmpty && scripture != 'N/A') ...[
                  const SizedBox(height: 5),
                  Text(
                    "Passagem Principal: $scripture",
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 12,
                        color: theme.colorScheme.secondary.withOpacity(0.9)),
                  ),
                ],
                const SizedBox(height: 10),
                if (relevantParagraphs.isNotEmpty) ...[
                  Text(
                    "Trechos Relevantes:",
                    style: theme.textTheme.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w500, fontSize: 13),
                  ),
                  const SizedBox(height: 5),
                  ...relevantParagraphs.take(2).map<Widget>((paragraph) {
                    // Mostrar apenas os 2 primeiros trechos
                    final String textPreview =
                        (paragraph['text_preview'] as String?) ??
                            "Trecho indisponível.";
                    final double paraScore =
                        (paragraph['score'] as num?)?.toDouble() ?? 0.0;
                    return Padding(
                      padding: const EdgeInsets.only(
                          top: 2.0, bottom: 5.0, left: 8.0),
                      child: Text(
                        '"${textPreview.length > 120 ? textPreview.substring(0, 120) + "..." : textPreview}" (Similaridade: ${paraScore.toStringAsFixed(2)})',
                        style: theme.textTheme.bodySmall?.copyWith(
                            height: 1.4,
                            fontSize: 11.5,
                            color: theme.textTheme.bodyMedium?.color
                                ?.withOpacity(0.85)),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 10),
                ],
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
