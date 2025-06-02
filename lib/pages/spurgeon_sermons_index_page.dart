// lib/pages/spurgeon_sermons_index_page.dart
import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';
import 'package:resumo_dos_deuses_flutter/pages/sermon_detail_page.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;
// Importe a SermonDetailPage quando estiver pronta
// import 'sermon_detail_page.dart';

class PreloadSermonItem {
  final String title; // Este será o título buscável (do preload JSON)
  final String generatedId; // ID do sermão (do preload JSON)
  final String bookAbbrev; // Livro onde está listado no preload JSON
  final String chapterNum; // Capítulo onde está listado no preload JSON

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

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_scrollListener);
    _titleSearchController.addListener(_onTitleSearchChanged);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    _titleSearchController.removeListener(_onTitleSearchChanged);
    _titleSearchController.dispose();
    _titleSearchDebounce?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      _bibleBooksMap = await BiblePageHelper.loadBooksMap();
      // <<< CARREGA APENAS O JSON DE PRÉ-CARREGAMENTO >>>
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
                    title: sermonEntry['title']
                        as String, // Título do preload JSON
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

  // Função para verificar se o título do sermão corresponde à query (tokenizada)
  bool _sermonMatchesTitleQuery(
      PreloadSermonItem sermon, String normalizedQuery) {
    if (normalizedQuery.isEmpty) return true;

    // O campo 'title' em PreloadSermonItem já é o que queremos buscar
    final normalizedTitleToSearch = _normalizeTextForSearch(sermon.title);

    final queryKeywords =
        normalizedQuery.split(' ').where((k) => k.isNotEmpty).toList();
    if (queryKeywords.isEmpty) return true;

    return queryKeywords
        .every((keyword) => normalizedTitleToSearch.contains(keyword));
  }

  // Função que obtém a lista filtrada baseada em TODOS os filtros
  List<PreloadSermonItem> _getSermonListBasedOnAllFilters() {
    List<PreloadSermonItem> filteredList = List.from(_allPreloadedSermons);

    // 1. Filtro por Título
    final normalizedTitleQuery = _normalizeTextForSearch(_titleSearchTerm);
    if (normalizedTitleQuery.isNotEmpty) {
      filteredList = filteredList.where((sermon) {
        return _sermonMatchesTitleQuery(sermon, normalizedTitleQuery);
      }).toList();
    }

    // 2. Filtro por Livro
    if (_selectedBookFilter != null) {
      filteredList = filteredList.where((sermon) {
        return sermon.bookAbbrev == _selectedBookFilter;
      }).toList();
    }

    // 3. Filtro por Capítulo (só se um livro também estiver selecionado)
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
      setState(() {
        _displayedSermons = allSermonsCopy.take(_displayCount).toList();
      });
    } else {
      setState(() {
        _displayedSermons = fullyFilteredList.take(_displayCount).toList();
      });
    }

    if (_scrollController.hasClients && !isInitialLoad) {
      // Evita scroll no carregamento inicial
      _scrollController.jumpTo(0.0);
    }

    if (isInitialLoad) setState(() => _isLoading = false);
  }

  void _loadMoreSermons() {
    if (!mounted || _allPreloadedSermons.isEmpty || _isLoadingMore) return;

    List<PreloadSermonItem> sourceListForMore =
        _getSermonListBasedOnAllFilters();

    if (_displayedSermons.length >= sourceListForMore.length) {
      return;
    }

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
          sermonTitle:
              sermonTitle, // Passa o título para o AppBar da DetailPage
        ),
      ),
    );
    // print("Navegando para detalhes do sermão: ID $sermonGeneratedId, Título: $sermonTitle"); // Pode manter para debug
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Sermões de C.H. Spurgeon"),
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
    // ... (O widget _buildFilterBar permanece o mesmo da resposta anterior)
    return Container(
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.1),
        border:
            Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Column(
        children: [
          TextField(
            controller: _titleSearchController,
            style: TextStyle(
                color: theme.textTheme.bodyLarge?.color, fontSize: 14),
            decoration: InputDecoration(
              hintText: "Buscar por título do sermão...",
              hintStyle: TextStyle(color: theme.hintColor, fontSize: 14),
              prefixIcon:
                  Icon(Icons.search, color: theme.iconTheme.color, size: 20),
              suffixIcon: _titleSearchController.text.isNotEmpty
                  ? IconButton(
                      icon: Icon(Icons.clear,
                          color: theme.iconTheme.color, size: 20),
                      onPressed: () {
                        _titleSearchController.clear();
                      },
                    )
                  : null,
              isDense: true,
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide(color: theme.dividerColor),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide:
                    BorderSide(color: theme.colorScheme.primary, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: <Widget>[
              Expanded(
                flex: 3,
                child: UtilsBiblePage.buildBookDropdown(
                  selectedBook: _selectedBookFilter,
                  booksMap: _bibleBooksMap,
                  onChanged: (String? newValue) {
                    setState(() {
                      _selectedBookFilter = newValue;
                      _selectedChapterFilter = null;
                      _applyFiltersAndDisplaySermons();
                    });
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: UtilsBiblePage.buildChapterDropdown(
                  selectedChapter: _selectedChapterFilter,
                  booksMap: _bibleBooksMap,
                  selectedBook: _selectedBookFilter,
                  onChanged: (int? newValue) {
                    setState(() {
                      _selectedChapterFilter = newValue;
                      _applyFiltersAndDisplaySermons();
                    });
                  },
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
    // ... (O widget _buildSermonsList permanece o mesmo da resposta anterior,
    //      lembrando de usar sermonItem.title para o título e
    //      sermonItem.generatedId para a navegação)
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
        final String title = sermonItem
            .title; // O título já está no formato desejado (do preload JSON)
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
