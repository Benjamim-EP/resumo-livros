// lib/pages/spurgeon_sermons_index_page.dart
import 'dart:convert';
import 'dart:math'; // Para Random
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/bible_page_helper.dart';
import 'package:resumo_dos_deuses_flutter/pages/biblie_page/utils.dart';
// Importe a futura página de detalhes do sermão
// import 'sermon_detail_page.dart';

// Modelo para informações de sermão do pré-carregamento
class PreloadSermonItem {
  final String title;
  final String generatedId;
  final String bookAbbrev; // Para saber de qual livro/capítulo ele veio
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
  // Armazena todos os sermões do preload_json de forma plana para facilitar aleatorização/filtragem
  List<PreloadSermonItem> _allPreloadedSermons = [];
  List<PreloadSermonItem> _displayedSermons = [];
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _bibleBooksMap; // Para nomes e capítulos dos livros
  String? _selectedBookFilter;
  int? _selectedChapterFilter;

  final Random _random = Random();
  final int _displayCount =
      20; // Quantos sermões mostrar por vez (para aleatórios ou filtrados)
  final ScrollController _scrollController = ScrollController();
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      _bibleBooksMap = await BiblePageHelper.loadBooksMap();
      final String preloadJsonString = await rootBundle
          .loadString('assets/sermons/preloading_spurgeon_sermons.json');
      final Map<String, dynamic> preloadData = json.decode(preloadJsonString);

      final List<PreloadSermonItem> allSermonsFlatList = [];
      preloadData.forEach((bookAbbrev, chaptersMap) {
        if (chaptersMap is Map) {
          (chaptersMap as Map<String, dynamic>)
              .forEach((chapterNum, chapterData) {
            if (chapterData is Map) {
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
      print("Erro ao carregar dados dos sermões: $e");
      print("Stack trace: $s");
      if (mounted) {
        setState(() {
          _error = "Falha ao carregar índice de sermões.";
          _isLoading = false;
        });
      }
    }
  }

  void _scrollListener() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        !_isLoadingMore) {
      // Se houver filtros aplicados, a paginação seria mais complexa
      // Por ora, a paginação de "carregar mais" só funciona para a lista inicial (sem filtros)
      if (_selectedBookFilter == null && _selectedChapterFilter == null) {
        _loadMoreSermons();
      }
    }
  }

  void _loadMoreSermons() {
    if (!mounted || _allPreloadedSermons.isEmpty) return;
    // Verifica se já mostrou todos os sermões disponíveis da lista _allPreloadedSermons
    if (_displayedSermons.length >= _allPreloadedSermons.length &&
        _selectedBookFilter == null &&
        _selectedChapterFilter == null) {
      print("Já mostrou todos os sermões disponíveis na lista aleatória.");
      return;
    }

    setState(() => _isLoadingMore = true);

    Future.delayed(const Duration(milliseconds: 300), () {
      if (!mounted) {
        setState(() => _isLoadingMore = false);
        return;
      }

      List<PreloadSermonItem> moreSermons = [];
      if (_selectedBookFilter == null && _selectedChapterFilter == null) {
        // Carrega mais aleatórios
        List<PreloadSermonItem> candidates = List.from(_allPreloadedSermons);
        candidates.shuffle(_random);
        int count = 0;
        for (var sermonCandidate in candidates) {
          if (!_displayedSermons
              .any((ds) => ds.generatedId == sermonCandidate.generatedId)) {
            moreSermons.add(sermonCandidate);
            count++;
            if (count >= _displayCount) break;
          }
        }
      } else {
        // Se filtros estão aplicados, não implementamos "carregar mais" para filtrados ainda.
        // A lista filtrada é exibida por completo.
        // Se quisesse paginação para filtrados, seria preciso buscar mais itens
        // da lista _allPreloadedSermons que correspondem ao filtro e não estão em _displayedSermons.
      }

      setState(() {
        _displayedSermons.addAll(moreSermons);
        _isLoadingMore = false;
      });
    });
  }

  void _applyFiltersAndDisplaySermons({bool isInitialLoad = false}) {
    if (!mounted) return;

    List<PreloadSermonItem> sermonsToDisplay = [];

    if (_selectedBookFilter == null && _selectedChapterFilter == null) {
      // Nenhum filtro, mostra aleatórios
      if (_allPreloadedSermons.isNotEmpty) {
        List<PreloadSermonItem> tempList = List.from(_allPreloadedSermons);
        tempList.shuffle(_random);
        sermonsToDisplay = tempList.take(_displayCount).toList();
      }
    } else {
      // Filtros aplicados
      sermonsToDisplay = _allPreloadedSermons.where((sermonItem) {
        bool bookMatch =
            true; // Se _selectedBookFilter for null, considera match
        if (_selectedBookFilter != null) {
          bookMatch = sermonItem.bookAbbrev == _selectedBookFilter;
        }

        bool chapterMatch =
            true; // Se _selectedChapterFilter for null, considera match
        if (bookMatch && _selectedChapterFilter != null) {
          chapterMatch =
              sermonItem.chapterNum == _selectedChapterFilter.toString();
        }
        return bookMatch && chapterMatch;
      }).toList();
      // Poderia adicionar .take(_displayCount) aqui também se quiser paginar os resultados filtrados
    }

    setState(() {
      _displayedSermons = sermonsToDisplay;
      if (isInitialLoad) _isLoading = false;
    });
  }

  void _navigateToSermonDetail(String sermonGeneratedId, String sermonTitle) {
    // TODO: Implementar navegação para SermonDetailPage
    // Navigator.push(
    //   context,
    //   MaterialPageRoute(
    //     builder: (context) => SermonDetailPage(
    //       sermonGeneratedId: sermonGeneratedId,
    //       sermonTitle: sermonTitle,
    //     ),
    //   ),
    // );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text(
              'Abrir Sermão: $sermonTitle (ID: $sermonGeneratedId) - Página de Detalhe não implementada.')),
    );
    print(
        "Navegar para detalhes do sermão: ID $sermonGeneratedId, Título: $sermonTitle");
  }

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
          _buildFilterBar(theme),
          Expanded(child: _buildSermonsList(theme)),
        ],
      ),
    );
  }

  Widget _buildFilterBar(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.cardColor.withOpacity(0.1), // Fundo sutil
        border:
            Border(bottom: BorderSide(color: theme.dividerColor, width: 0.5)),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            flex: 3,
            child: UtilsBiblePage.buildBookDropdown(
              // Reutilizando o widget da BiblePage
              selectedBook: _selectedBookFilter,
              booksMap: _bibleBooksMap,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedBookFilter = newValue;
                  _selectedChapterFilter =
                      null; // Reseta o capítulo ao mudar o livro
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: UtilsBiblePage.buildChapterDropdown(
              // Reutilizando o widget da BiblePage
              selectedChapter: _selectedChapterFilter,
              booksMap: _bibleBooksMap,
              selectedBook:
                  _selectedBookFilter, // Passa o livro selecionado para habilitar/desabilitar
              onChanged: (int? newValue) {
                setState(() {
                  _selectedChapterFilter = newValue;
                });
              },
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.search),
            tooltip: "Aplicar Filtros",
            onPressed: () => _applyFiltersAndDisplaySermons(),
            color: theme.colorScheme.primary,
            splashRadius: 20,
          ),
          IconButton(
            icon: Icon(Icons.clear,
                color: theme.iconTheme.color?.withOpacity(0.7)),
            tooltip: "Limpar Filtros",
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
    );
  }

  Widget _buildSermonsList(ThemeData theme) {
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
    if (_displayedSermons.isEmpty &&
        (_selectedBookFilter != null || _selectedChapterFilter != null)) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Nenhum sermão encontrado para os filtros aplicados.",
              style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
        ),
      );
    }
    if (_displayedSermons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text("Carregando sermões ou nenhum para exibir...",
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
                  child: Center(child: CircularProgressIndicator()),
                )
              : const SizedBox
                  .shrink(); // Se não está carregando mais, não mostra nada
        }

        final sermonItem = _displayedSermons[index];
        // Como _displayedSermons agora é List<PreloadSermonItem>, acessamos os campos diretamente.
        final String title = sermonItem.title;
        final String generatedId = sermonItem.generatedId;
        // Para exibir a referência do sermão no card, podemos usar sermonItem.bookAbbrev e sermonItem.chapterNum
        final String bookName = _bibleBooksMap?[sermonItem.bookAbbrev]
                ?['nome'] ??
            sermonItem.bookAbbrev.toUpperCase();
        final String referenceText = "$bookName ${sermonItem.chapterNum}";

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
              child: Text("Referência Principal (Índice): $referenceText",
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
