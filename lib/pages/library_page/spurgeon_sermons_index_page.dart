// lib/pages/library_page/spurgeon_sermons_index_page.dart
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_redux/flutter_redux.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:septima_biblia/components/bottomNavigationBar/bottomNavigationBar.dart'; // Para _UserCoinsViewModel
import 'package:septima_biblia/components/login_required.dart';
import 'package:septima_biblia/pages/biblie_page/bible_page_helper.dart';
import 'package:septima_biblia/pages/biblie_page/utils.dart';
import 'package:septima_biblia/pages/library_page/sermon_card.dart';
import 'package:septima_biblia/pages/purschase_pages/subscription_selection_page.dart';
import 'package:septima_biblia/pages/sermon_detail_page.dart';
import 'package:septima_biblia/pages/sermons/sermon_chat_page.dart';
import 'package:septima_biblia/redux/actions.dart';
import 'package:septima_biblia/redux/actions/sermon_search_actions.dart';
import 'package:septima_biblia/redux/reducers.dart';
import 'package:septima_biblia/redux/reducers/sermon_search_reducer.dart';
import 'package:septima_biblia/redux/reducers/subscription_reducer.dart';
import 'package:septima_biblia/redux/store.dart';
import 'package:septima_biblia/services/interstitial_manager.dart';
import 'package:unorm_dart/unorm_dart.dart' as unorm;
import 'package:redux/redux.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class _SermonsViewModel {
  final bool isPremium;
  final SermonSearchState sermonSearchState;
  final SermonState sermonState;

  _SermonsViewModel({
    required this.isPremium,
    required this.sermonSearchState,
    required this.sermonState,
  });

  static _SermonsViewModel fromStore(Store<AppState> store) {
    // --- INÍCIO DA LÓGICA CORRIGIDA E COMPLETA ---
    bool premiumStatus = false;

    // 1. Verifica o estado da assinatura no Redux primeiro (feedback rápido pós-compra)
    if (store.state.subscriptionState.status ==
        SubscriptionStatus.premiumActive) {
      premiumStatus = true;
    } else {
      // 2. Como fallback, verifica a fonte de verdade do Firestore (userDetails)
      final userDetails = store.state.userState.userDetails;
      if (userDetails != null) {
        final statusString = userDetails['subscriptionStatus'] as String?;
        final endDate =
            (userDetails['subscriptionEndDate'] as Timestamp?)?.toDate();

        if (statusString == 'active' &&
            endDate != null &&
            endDate.isAfter(DateTime.now())) {
          premiumStatus = true;
        }
      }
    }
    // --- FIM DA LÓGICA CORRIGIDA ---

    return _SermonsViewModel(
      isPremium: premiumStatus, // Usa a variável calculada
      sermonSearchState: store.state.sermonSearchState,
      sermonState: store.state.sermonState,
    );
  }
}

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

class _SpurgeonSermonsIndexPageState extends State<SpurgeonSermonsIndexPage>
    with SingleTickerProviderStateMixin {
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
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // <<< INICIALIZAR
    _loadInitialPreloadedData();

    _preloadScrollController.addListener(_scrollListenerForPreload);
    _localTitleSearchController.addListener(_onLocalTitleSearchChanged);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final store = StoreProvider.of<AppState>(context, listen: false);
        store.dispatch(LoadSermonFavoritesAction());
        store.dispatch(LoadSermonProgressAction());
        if (store.state.sermonSearchState.searchHistory.isEmpty &&
            !store.state.sermonSearchState.isLoadingHistory) {
          store.dispatch(LoadSermonSearchHistoryAction());
        }
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _preloadScrollController.removeListener(_scrollListenerForPreload);
    _preloadScrollController.dispose();
    _localTitleSearchController.removeListener(_onLocalTitleSearchChanged);
    _localTitleSearchController.dispose();
    _semanticSermonSearchController.dispose();
    _localTitleSearchDebounce?.cancel();
    super.dispose();
  }

  void _toggleSermonParagraphsExpansion(String sermonIdBase) {
    if (!mounted) return;
    setState(() {
      if (_expandedSermonResultId == sermonIdBase) {
        _expandedSermonResultId = null;
      } else {
        _expandedSermonResultId = sermonIdBase;
      }
    });
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
      StoreProvider.of<AppState>(context, listen: false)
          .dispatch(SearchSermonsAction(query: query));
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

    // O StoreConnector agora envolve todo o Scaffold, fornecendo o viewModel
    // para todas as partes da UI, incluindo as abas.
    return StoreConnector<AppState, _SermonsViewModel>(
      converter: (store) => _SermonsViewModel.fromStore(store),
      builder: (context, viewModel) {
        return Scaffold(
          appBar: AppBar(
            title: Text(_isSemanticSearchModeActive
                ? "Busca Inteligente de Sermões"
                : "Sermões de C.H. Spurgeon"),
            backgroundColor: theme.appBarTheme.backgroundColor,
            foregroundColor: theme.appBarTheme.foregroundColor,
            // A TabBar é colocada na propriedade 'bottom' da AppBar
            bottom: PreferredSize(
              // ✅ CORREÇÃO AQUI: Aumente este valor.
              // Um valor entre 110.0 e 120.0 deve ser suficiente para a barra de busca e as abas.
              preferredSize: const Size.fromHeight(112.0),
              child: Column(
                children: [
                  // --- Barra de Busca (lógica movida para cá) ---
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 8.0),
                    child: Row(
                      // ... (a lógica da barra de busca que você já tem permanece aqui)
                      children: [
                        IconButton(
                          icon: SvgPicture.asset(
                            'assets/icons/buscasemantica.svg',
                            colorFilter: ColorFilter.mode(
                                _isSemanticSearchModeActive
                                    ? theme.colorScheme.primary
                                    : (theme.iconTheme.color
                                            ?.withOpacity(0.7) ??
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
                                    color:
                                        theme.iconTheme.color?.withOpacity(0.9),
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
                  // Seletor de Abas
                  TabBar(
                    controller: _tabController,
                    tabs: const [
                      Tab(icon: Icon(Icons.explore_outlined), text: "Explorar"),
                      Tab(icon: Icon(Icons.star_outline), text: "Favoritos"),
                      Tab(
                          icon: Icon(Icons.watch_later_outlined),
                          text: "Continuar"),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // O corpo do Scaffold agora é a TabBarView
          body: TabBarView(
            controller: _tabController,
            children: [
              // <<< CORREÇÃO AQUI: Lógica condicional para a primeira aba >>>
              _isSemanticSearchModeActive
                  ? _buildSemanticSearchUI(theme, viewModel.sermonSearchState)
                  : _buildExplorarTab(theme, viewModel),
              _buildFavoritosTab(theme, viewModel),
              _buildContinuarLendoTab(theme, viewModel),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              final store = StoreProvider.of<AppState>(context, listen: false);
              if (store.state.userState.isGuestUser) {
                showLoginRequiredDialog(context,
                    featureName: "o chat com Spurgeon AI");
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (context) => const SermonChatPage()),
                );
              }
            },
            label: const Text("Conversar com IA"),
            icon: const Icon(Icons.chat_bubble_outline),
            tooltip: "Faça perguntas sobre os sermões de Spurgeon",
          ),
        );
      },
    );
  }

  /// Constrói a aba "Explorar", que mostra a lista de sermões filtrada ou aleatória.
  Widget _buildExplorarTab(ThemeData theme, _SermonsViewModel viewModel) {
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
      ));
    }

    return Column(
      children: [
        // A barra de filtros é o primeiro widget da coluna
        _buildFilterBarForPreload(theme, viewModel.isPremium),

        // O Expanded garante que a lista ocupe o resto do espaço
        Expanded(
          child: _displayedSermonsFromPreload.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Text(
                      "Nenhum sermão encontrado para os filtros aplicados.",
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.builder(
                  controller: _preloadScrollController,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8.0, vertical: 4.0),
                  itemCount: _displayedSermonsFromPreload.length +
                      (_isLoadingMorePreload ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == _displayedSermonsFromPreload.length) {
                      return const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.0),
                        child: Center(child: CircularProgressIndicator()),
                      );
                    }
                    final sermonItem = _displayedSermonsFromPreload[index];
                    final progressData = viewModel
                        .sermonState.sermonProgress[sermonItem.generatedId];

                    return SermonCard(
                      title: sermonItem.title,
                      reference:
                          "${_bibleBooksMap?[sermonItem.bookAbbrev]?['nome'] ?? ''} ${sermonItem.chapterNum}",
                      progress: progressData?.progressPercent ?? 0.0,
                      onTap: () {
                        // AQUI ESTÁ A VERIFICAÇÃO CRÍTICA
                        if (!viewModel.isPremium) {
                          // Se NÃO for premium, mostra o anúncio e depois navega.
                          interstitialManager
                              .tryShowInterstitial(
                                  fromScreen: "SermonList_to_SermonDetail")
                              .then((_) {
                            if (mounted) {
                              _navigateToSermonDetail(
                                  sermonItem.generatedId, sermonItem.title);
                            }
                          });
                        } else {
                          // Se FOR premium, apenas navega diretamente.
                          _navigateToSermonDetail(
                              sermonItem.generatedId, sermonItem.title);
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// Constrói a aba "Favoritos", mostrando apenas os sermões favoritados.
  Widget _buildFavoritosTab(ThemeData theme, _SermonsViewModel viewModel) {
    final favoritedIds = viewModel.sermonState.favoritedSermonIds;

    if (viewModel.sermonState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (favoritedIds.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "Você ainda não favoritou nenhum sermão.\nToque na estrela na página do sermão para adicioná-lo aqui.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Filtra a lista principal de sermões para pegar apenas os favoritos
    final favoriteSermons = _allPreloadedSermons
        .where((s) => favoritedIds.contains(s.generatedId))
        .toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      itemCount: favoriteSermons.length,
      itemBuilder: (context, index) {
        final sermonItem = favoriteSermons[index];
        final progressData =
            viewModel.sermonState.sermonProgress[sermonItem.generatedId];

        return SermonCard(
          title: sermonItem.title,
          reference:
              "${_bibleBooksMap?[sermonItem.bookAbbrev]?['nome'] ?? ''} ${sermonItem.chapterNum}",
          progress: progressData?.progressPercent ?? 0.0,
          onTap: () =>
              _navigateToSermonDetail(sermonItem.generatedId, sermonItem.title),
        );
      },
    );
  }

  /// Constrói a aba "Continuar Lendo", mostrando sermões com progresso e ordenando pelos mais recentes.
  Widget _buildContinuarLendoTab(ThemeData theme, _SermonsViewModel viewModel) {
    final progressMap = viewModel.sermonState.sermonProgress;

    if (viewModel.sermonState.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (progressMap.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "Comece a ler um sermão e seu progresso aparecerá aqui para você continuar de onde parou.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Filtra os sermões que têm progresso salvo e não estão concluídos
    final inProgressSermons = _allPreloadedSermons
        .where((s) =>
            progressMap.containsKey(s.generatedId) &&
            (progressMap[s.generatedId]!.progressPercent < 0.98))
        .toList();

    // Ordena a lista pelos mais recentemente lidos
    inProgressSermons.sort((a, b) {
      final timestampA = progressMap[a.generatedId]!.lastReadTimestamp;
      final timestampB = progressMap[b.generatedId]!.lastReadTimestamp;
      return timestampB.compareTo(timestampA); // Mais recente primeiro
    });

    if (inProgressSermons.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Text(
            "Você leu todos os sermões que começou! \nExplore novos na aba 'Explorar'.",
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      itemCount: inProgressSermons.length,
      itemBuilder: (context, index) {
        final sermonItem = inProgressSermons[index];
        final progressData =
            viewModel.sermonState.sermonProgress[sermonItem.generatedId];

        return SermonCard(
          title: sermonItem.title,
          reference:
              "${_bibleBooksMap?[sermonItem.bookAbbrev]?['nome'] ?? ''} ${sermonItem.chapterNum}",
          progress: progressData?.progressPercent ?? 0.0,
          onTap: () =>
              _navigateToSermonDetail(sermonItem.generatedId, sermonItem.title),
        );
      },
    );
  }

  Widget _buildFilterBarForPreload(ThemeData theme, bool isPremium) {
    // A variável isPremium não é mais necessária aqui, mas a mantemos para
    // evitar quebrar a chamada do método no build, caso queira usá-la para outra coisa no futuro.

    final Widget filterBarContent = Row(
      children: <Widget>[
        // <<< 1. ÍCONE DE CADEADO REMOVIDO >>>
        // A verificação `if (!isPremium)` e o ícone de cadeado foram removidos daqui.

        Expanded(
          flex: 2,
          child: UtilsBiblePage.buildBookDropdown(
            context: context,
            selectedBook: _selectedBookFilterLocal,
            booksMap: _bibleBooksMap,
            onChanged: (String? newValue) {
              // <<< 2. BLOQUEIO REMOVIDO DO ONCHANGED >>>
              // A linha 'if (!isPremium) return;' foi removida.
              setState(() {
                _selectedBookFilterLocal = newValue;
                _selectedChapterFilterLocal = null;
                _applyLocalFiltersAndDisplayPreloadedSermons();
              });
            },
            backgroundColor:
                (theme.inputDecorationTheme.fillColor ?? theme.cardColor)
                    .withOpacity(0.4),
            // <<< 3. ESTILO UNIFICADO (NÃO DEPENDE MAIS DE isPremium) >>>
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
              // <<< 2. BLOQUEIO REMOVIDO DO ONCHANGED >>>
              // A linha 'if (!isPremium) return;' foi removida.
              setState(() {
                _selectedChapterFilterLocal = newValue;
                _applyLocalFiltersAndDisplayPreloadedSermons();
              });
            },
            backgroundColor:
                (theme.inputDecorationTheme.fillColor ?? theme.cardColor)
                    .withOpacity(0.4),
            // <<< 3. ESTILO UNIFICADO (NÃO DEPENDE MAIS DE isPremium) >>>
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
    );

    // <<< 4. WRAPPER DE BLOQUEIO REMOVIDO >>>
    // Agora o Container é retornado diretamente, sem o GestureDetector e AbsorbPointer.
    return Container(
      padding: const EdgeInsets.fromLTRB(12.0, 0, 12.0, 8.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
            bottom: BorderSide(
                color: theme.dividerColor.withOpacity(0.2), width: 1)),
      ),
      child: filterBarContent, // Retorna o conteúdo diretamente
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
                  style:
                      TextStyle(color: theme.colorScheme.error, fontSize: 16),
                  textAlign: TextAlign.center)));
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
                      color:
                          theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                  textAlign: TextAlign.center)));
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
            title: Text(sermonItem.title,
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
            onTap: () => _navigateToSermonDetail(
                sermonItem.generatedId, sermonItem.title),
          ),
        );
      },
    );
  }

  Widget _buildErrorWidget({
    required BuildContext context,
    required ThemeData theme,
    required String message,
    required String details,
    required VoidCallback onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: SingleChildScrollView(
          // Para evitar overflow em telas menores
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.cloud_off_rounded, // Ícone diferente para variar
                color: theme.iconTheme.color?.withOpacity(0.5),
                size: 60,
              ),
              const SizedBox(height: 20),
              Text(
                message,
                style: theme.textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                details,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                icon: const Icon(Icons.refresh_rounded),
                label: const Text("Tentar Novamente"),
                onPressed: onRetry,
              )
            ],
          ),
        ),
      ),
    );
  }

  // <<< FUNÇÃO MODIFICADA >>>
  Widget _buildSemanticSearchUI(
      ThemeData theme, SermonSearchState sermonSearchState) {
    // 1. Loading...
    if (sermonSearchState.isLoading &&
        sermonSearchState.currentSermonQuery.isNotEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Erro na busca (AQUI ESTÁ A MUDANÇA)
    if (!sermonSearchState.isLoading && sermonSearchState.error != null) {
      return _buildErrorWidget(
        context: context,
        theme: theme,
        message: "Não foi possível carregar os resultados.",
        details: "Verifique sua conexão com a internet e tente novamente.",
        onRetry: () {
          // Redispacha a busca com a última query tentada
          if (sermonSearchState.currentSermonQuery.isNotEmpty) {
            StoreProvider.of<AppState>(context, listen: false).dispatch(
                SearchSermonsAction(
                    query: sermonSearchState.currentSermonQuery));
          }
        },
      );
    }

    // 3. Resultados da busca...
    if (sermonSearchState.sermonResults.isNotEmpty) {
      return _buildSemanticSearchResultsList(
          theme, sermonSearchState.sermonResults);
    }

    // 4. Histórico de busca...
    if (sermonSearchState.currentSermonQuery.isEmpty &&
        sermonSearchState.searchHistory.isNotEmpty) {
      return _buildSearchHistoryList(theme, sermonSearchState.searchHistory);
    }

    // 5. Nenhum resultado encontrado...
    if (!sermonSearchState.isLoading &&
        sermonSearchState.sermonResults.isEmpty &&
        sermonSearchState.currentSermonQuery.isNotEmpty) {
      return Center(
          child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                  "Nenhum sermão encontrado para '${sermonSearchState.currentSermonQuery}'.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium)));
    }

    // 6. Mensagem inicial...
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          sermonSearchState.isLoadingHistory
              ? "Carregando histórico de sermões..."
              : "Use a busca inteligente para encontrar sermões por tema ou sentimento.",
          style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildSearchHistoryList(
      ThemeData theme, List<Map<String, dynamic>> history) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
          child: Text("Histórico de Buscas de Sermões:",
              style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.9))),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: history.length,
            itemBuilder: (context, index) {
              final historyEntry = history[index];
              final String query =
                  historyEntry['query'] as String? ?? 'Busca inválida';
              final DateTime? timestamp =
                  DateTime.tryParse(historyEntry['timestamp'] as String? ?? '');
              return ListTile(
                leading: Icon(Icons.history,
                    color: theme.iconTheme.color?.withOpacity(0.6)),
                title: Text(query, style: theme.textTheme.bodyLarge),
                subtitle: timestamp != null
                    ? Text(
                        DateFormat('dd/MM/yy HH:mm')
                            .format(timestamp.toLocal()),
                        style: theme.textTheme.bodySmall)
                    : null,
                trailing: Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: theme.iconTheme.color?.withOpacity(0.5)),
                onTap: () {
                  _semanticSermonSearchController.text = query;
                  StoreProvider.of<AppState>(context, listen: false).dispatch(
                      ViewSermonSearchFromHistoryAction(historyEntry));
                },
              );
            },
          ),
        ),
      ],
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
            sermonData['sermon_id_base'] as String? ?? 'sermon_result_$index';
        final String title =
            sermonData['title_translated'] as String? ?? 'Sermão Sem Título';
        final String scripture =
            sermonData['main_scripture_abbreviated'] as String? ?? 'N/A';
        final String preacher =
            sermonData['preacher'] as String? ?? 'C.H. Spurgeon';
        final List<String> relevantParagraphsTexts =
            (sermonData['relevant_paragraphs'] as List<dynamic>? ?? [])
                .map((p) => p['text_preview'] as String? ?? '')
                .where((p) => p.isNotEmpty)
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
                Text(title,
                    style: theme.textTheme.titleLarge?.copyWith(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Text("Por: $preacher",
                    style: theme.textTheme.bodySmall?.copyWith(
                        fontStyle: FontStyle.italic,
                        fontSize: 11.5,
                        color: theme.textTheme.bodySmall?.color
                            ?.withOpacity(0.75))),
                if (scripture.isNotEmpty && scripture != 'N/A') ...[
                  const SizedBox(height: 4),
                  Text("Passagem Principal: $scripture",
                      style: theme.textTheme.bodySmall?.copyWith(
                          fontSize: 11.5,
                          color: theme.colorScheme.secondary.withOpacity(0.9))),
                ],
                if (relevantParagraphsTexts.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                      '"${relevantParagraphsTexts.first.length > 150 ? relevantParagraphsTexts.first.substring(0, 150) + "..." : relevantParagraphsTexts.first}"',
                      style: theme.textTheme.bodyMedium?.copyWith(
                          height: 1.4,
                          fontSize: 13,
                          color: theme.colorScheme.onSurface.withOpacity(0.75),
                          fontStyle: FontStyle.italic),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 10),
                if (relevantParagraphsTexts.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      icon: Icon(
                          isExpanded
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                          color: theme.colorScheme.secondary),
                      label: Text(
                          isExpanded
                              ? "Ocultar Parágrafos"
                              : "Ver Todos os Parágrafos (${relevantParagraphsTexts.length})",
                          style: TextStyle(
                              fontSize: 12,
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.w500)),
                      style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                      onPressed: () =>
                          _toggleSermonParagraphsExpansion(sermonIdBase),
                    ),
                  ),
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
                          return Padding(
                            padding: EdgeInsets.only(
                                bottom: entry.key <
                                        relevantParagraphsTexts.length - 1
                                    ? 12.0
                                    : 0.0),
                            child: SelectableText(entry.value,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    height: 1.55,
                                    color: theme.colorScheme.onSurfaceVariant
                                        .withOpacity(0.9)),
                                textAlign: TextAlign.justify),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
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
                    onPressed: () =>
                        _navigateToSermonDetail(sermonIdBase, title),
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
