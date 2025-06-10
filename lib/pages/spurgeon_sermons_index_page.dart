// lib/pages/spurgeon_sermons_index_page.dart
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart'; // <<< IMPORTAR SVG
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';
import 'package:resumo_dos_deuses_flutter/pages/sermon_detail_page.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;

// ... (Modelo PreloadSermonItem permanece o mesmo) ...
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
  // ... (variáveis de estado existentes) ...
  List<PreloadSermonItem> _allPreloadedSermons = [];
  List<PreloadSermonItem> _displayedSermons = [];
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _bibleBooksMap;
  String? _selectedBookFilter;
  int? _selectedChapterFilter;

  final TextEditingController _titleSearchController = TextEditingController();
  String _titleSearchTerm = "";
  Timer? _titleSearchDebounce;

  final Random _random = Random();
  final int _displayCount = 20;
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  // <<< NOVO ESTADO PARA O TOGGLE DA BUSCA SEMÂNTICA >>>
  bool _isSemanticSearchForSermonsActive = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_scrollListener);
    _titleSearchController.addListener(_onTitleSearchChanged);
  }

  @override
  void dispose() {
    // ... (dispose existente) ...
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _titleSearchController.removeListener(_onTitleSearchChanged);
    _titleSearchController.dispose();
    _titleSearchDebounce?.cancel();
    super.dispose();
  }

  // ... (_loadInitialData, _onTitleSearchChanged, _scrollListener,
  //      _normalizeTextForSearch, _sermonMatchesTitleQuery,
  //      _getSermonListBasedOnAllFilters, _applyFiltersAndDisplaySermons,
  //      _loadMoreSermons, _navigateToSermonDetail permanecem os mesmos da última versão)
  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
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
          _applyFiltersAndDisplaySermons(isInitialLoad: true);
          _isLoading = false;
        });
      }
    } catch (e, s) {
      print("Erro ao carregar dados dos sermões (preload): $e\n$s");
      if (mounted)
        setState(() {
          _error = "Falha ao carregar índice de sermões.";
          _isLoading = false;
        });
    }
  }

  void _onTitleSearchChanged() {
    if (_titleSearchDebounce?.isActive ?? false) _titleSearchDebounce!.cancel();
    _titleSearchDebounce = Timer(const Duration(milliseconds: 500), () {
      if (mounted && _titleSearchController.text != _titleSearchTerm) {
        setState(() {
          _titleSearchTerm = _titleSearchController.text;
          _applyFiltersAndDisplaySermons();
        });
      } else if (mounted &&
          _titleSearchController.text.isEmpty &&
          _titleSearchTerm.isNotEmpty) {
        setState(() {
          _titleSearchTerm = "";
          _applyFiltersAndDisplaySermons();
        });
      }
    });
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 300 &&
        !_isLoadingMore) {
      _loadMoreSermons();
    }
  }

  String _normalizeTextForSearch(String text) {
    if (text.isEmpty) return "";
    return unorm
        .nfd(text)
        .replaceAll(RegExp(r'[\u0300-\u036f]'), '')
        .toLowerCase();
  }

  bool _sermonMatchesTitleQuery(
      PreloadSermonItem sermon, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;
    final normalizedTitleToSearch = _normalizeTextForSearch(sermon.title);
    final queryKeywords =
        normalizedQuery.split(' ').where((k) => k.isNotEmpty).toList();
    if (queryKeywords.isEmpty) return true;
    return queryKeywords
        .every((keyword) => normalizedTitleToSearch.contains(keyword));
  }

  List<PreloadSermonItem> _getSermonListBasedOnAllFilters() {
    List<PreloadSermonItem> filteredList = List.from(_allPreloadedSermons);
    final normalizedTitleQuery = _normalizeTextForSearch(_titleSearchTerm);
    if (normalizedTitleQuery.isNotEmpty) {
      filteredList = filteredList.where((sermon) {
        return _sermonMatchesTitleQuery(sermon, normalizedTitleQuery);
      }).toList();
    }
    if (_selectedBookFilter != null) {
      filteredList = filteredList.where((sermon) {
        return sermon.bookAbbrev == _selectedBookFilter;
      }).toList();
    }
    if (_selectedBookFilter != null && _selectedChapterFilter != null) {
      filteredList = filteredList.where((sermon) {
        return sermon.chapterNum == _selectedChapterFilter.toString();
      }).toList();
    }
    return filteredList;
  }

  void _applyFiltersAndDisplaySermons({bool isInitialLoad = false}) {
    if (!mounted) return;
    List<PreloadSermonItem> fullyFilteredList =
        _getSermonListBasedOnAllFilters();
    if (_titleSearchTerm.isEmpty &&
        _selectedBookFilter == null &&
        _selectedChapterFilter == null) {
      List<PreloadSermonItem> allSermonsCopy = List.from(_allPreloadedSermons);
      allSermonsCopy.shuffle(_random);
      setState(() =>
          _displayedSermons = allSermonsCopy.take(_displayCount).toList());
    } else {
      setState(() =>
          _displayedSermons = fullyFilteredList.take(_displayCount).toList());
    }
    if (_scrollController.hasClients && !isInitialLoad)
      _scrollController.jumpTo(0.0);
    if (isInitialLoad) setState(() => _isLoading = false);
  }

  void _loadMoreSermons() {
    if (!mounted || _allPreloadedSermons.isEmpty || _isLoadingMore) return;
    List<PreloadSermonItem> sourceListForMore =
        _getSermonListBasedOnAllFilters();
    if (_displayedSermons.length >= sourceListForMore.length) return;
    setState(() => _isLoadingMore = true);
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!mounted) {
        setState(() => _isLoadingMore = false);
        return;
      }
      final currentCount = _displayedSermons.length;
      final List<PreloadSermonItem> nextBatch =
          sourceListForMore.skip(currentCount).take(_displayCount).toList();
      setState(() {
        _displayedSermons.addAll(nextBatch);
        _isLoadingMore = false;
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sermões de C.H. Spurgeon"),
        // backgroundColor e foregroundColor virão do tema global
      ),
      body: Column(
        children: [
          _buildFilterBar(theme),
          Expanded(child: _buildSermonsList(theme)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    Color svgIconColor = _isSemanticSearchForSermonsActive
        ? Color.fromARGB(255, 255, 224, 87) // Cor quando ativo
        : theme.iconTheme.color?.withOpacity(0.7) ??
            theme.hintColor; // Cor quando inativo

    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
          color:
              theme.scaffoldBackgroundColor, // Cor de fundo da barra de filtro
          border: Border(
              bottom: BorderSide(
                  color: theme.dividerColor.withOpacity(0.5), width: 0.5)),
          boxShadow: [
            // Sombra sutil para destacar a barra de filtro
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ]),
      child: Column(
        children: [
          Row(
            // Row para o TextField e o botão SVG
            children: [
              Expanded(
                child: TextField(
                  controller: _titleSearchController,
                  style: TextStyle(
                      color: theme.textTheme.bodyLarge?.color, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: "Buscar por título do sermão...",
                    hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
                    prefixIcon: Icon(Icons.search,
                        color: theme.iconTheme.color?.withOpacity(0.7),
                        size: 20),
                    suffixIcon: _titleSearchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: theme.iconTheme.color?.withOpacity(0.7),
                                size: 20),
                            tooltip: "Limpar busca por título",
                            onPressed: () {
                              _titleSearchController.clear();
                              // O listener _onTitleSearchChanged já chamará _applyFiltersAndDisplaySermons
                            },
                          )
                        : null,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 10, horizontal: 12),
                    filled: true,
                    fillColor: theme.inputDecorationTheme.fillColor ??
                        theme.cardColor.withOpacity(0.5),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(
                          8.0), // Bordas um pouco menos arredondadas
                      borderSide: BorderSide(
                          color: theme.dividerColor.withOpacity(0.7)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                          color: theme.dividerColor.withOpacity(0.5)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8.0),
                      borderSide: BorderSide(
                          color: theme.colorScheme.primary, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // <<< BOTÃO SVG PARA TOGGLE DE BUSCA SEMÂNTICA >>>
              IconButton(
                icon: SvgPicture.asset(
                  'assets/icons/buscasemantica.svg',
                  colorFilter: ColorFilter.mode(svgIconColor, BlendMode.srcIn),
                  width: 24,
                  height: 24,
                ),
                tooltip: _isSemanticSearchForSermonsActive
                    ? "Desativar Busca Semântica (não implementado)"
                    : "Ativar Busca Semântica (não implementado)",
                onPressed: () {
                  setState(() {
                    _isSemanticSearchForSermonsActive =
                        !_isSemanticSearchForSermonsActive;
                    // Por enquanto, apenas muda a cor. A lógica de busca semântica real virá depois.
                    if (_isSemanticSearchForSermonsActive) {
                      print("Modo de busca semântica ATIVADO (visualmente)");
                      // Aqui você poderia, no futuro, alterar o placeholder do TextField, por exemplo.
                    } else {
                      print("Modo de busca semântica DESATIVADO (visualmente)");
                    }
                  });
                },
                splashRadius: 22,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: UtilsBiblePage.buildBookDropdown(
                  context: context,
                  selectedBook: _selectedBookFilter,
                  booksMap: _bibleBooksMap,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedBookFilter = newValue;
                      _selectedChapterFilter = null;
                      _applyFiltersAndDisplaySermons();
                    });
                  },
                  backgroundColor: theme.inputDecorationTheme.fillColor ??
                      theme.cardColor.withOpacity(0.5),
                  textColor: theme.textTheme.bodyLarge?.color,
                  iconColor: theme.iconTheme.color?.withOpacity(0.7),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: UtilsBiblePage.buildChapterDropdown(
                  context: context,
                  selectedChapter: _selectedChapterFilter,
                  booksMap: _bibleBooksMap,
                  selectedBook: _selectedBookFilter,
                  onChanged: (int? newValue) {
                    setState(() {
                      _selectedChapterFilter = newValue;
                      _applyFiltersAndDisplaySermons();
                    });
                  },
                  backgroundColor: theme.inputDecorationTheme.fillColor ??
                      theme.cardColor.withOpacity(0.5),
                  textColor: theme.textTheme.bodyLarge?.color,
                  iconColor: theme.iconTheme.color?.withOpacity(0.7),
                ),
              ),
              IconButton(
                icon: Icon(Icons.filter_list_off,
                    color: theme.iconTheme.color?.withOpacity(0.7)),
                tooltip: "Limpar Filtros de Livro/Cap.",
                onPressed: () {
                  setState(() {
                    _selectedBookFilter = null;
                    _selectedChapterFilter = null;
                    _applyFiltersAndDisplaySermons();
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

  Widget _buildSermonsList(ThemeData theme) {
    // ... (o método _buildSermonsList permanece o mesmo da resposta anterior)
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 16),
              textAlign: TextAlign.center),
        ),
      );
    }
    if (_displayedSermons.isEmpty) {
      String message = "Nenhum sermão para exibir no momento.";
      if (_titleSearchTerm.isNotEmpty ||
          _selectedBookFilter != null ||
          _selectedChapterFilter != null) {
        message = "Nenhum sermão encontrado para os filtros aplicados.";
      }
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(message,
              style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8.0),
      itemCount: _displayedSermons.length + (_isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == _displayedSermons.length) {
          return _isLoadingMore
              ? const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16.0),
                  child: Center(child: CircularProgressIndicator()))
              : const SizedBox.shrink();
        }

        final sermonItem = _displayedSermons[index];
        final String title = sermonItem.title;
        final String generatedId = sermonItem.generatedId;

        final String bookName = _bibleBooksMap?[sermonItem.bookAbbrev]
                ?['nome'] ??
            sermonItem.bookAbbrev.toUpperCase();
        final String referenceHint = "$bookName ${sermonItem.chapterNum}";

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 4.0),
          elevation: 2,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            title: Text(title,
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w500)),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text("Indexado em: $referenceHint",
                  style: theme.textTheme.bodySmall?.copyWith(
                      color:
                          theme.textTheme.bodySmall?.color?.withOpacity(0.8))),
            ),
            trailing: Icon(Icons.arrow_forward_ios,
                size: 16, color: theme.iconTheme.color?.withOpacity(0.6)),
            onTap: () => _navigateToSermonDetail(generatedId, title),
          ),
        );
      },
    );
  }
}
